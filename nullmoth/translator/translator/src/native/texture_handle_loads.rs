//! A texture or sampler read out of memory as a 64-bit integer and turned into a handle with `inttoptr` becomes a plain
//! handle load.
//!
//! WebKit's WGSL compiler writes a texture held in an argument buffer as its resource ID: the AIR loads the field as an
//! `i64` and converts it (`%h = load i64, ptr addrspace(2) %field` / `%t = inttoptr i64 %h to ptr addrspace(1)`), where
//! the Metal compiler itself loads the handle (`%t = load ptr addrspace(1), ptr addrspace(2) %field`). Both read the
//! same eight bytes. The translator models the second form only: reflection, the argument-buffer texture paths and the
//! bindless heap all start from a pointer-typed load. The integer form reached the emitter as an `inttoptr` of an
//! unknown integer, which it either took for a device address (the device-address model defines no value for it, so
//! the texture's next use failed with "unknown SSA value") or for an unmodeled pointer (a private null, so the texture
//! read nothing and its size was zero).
//!
//! The rewrite applies when the integer has no use but `inttoptr`s whose results are textures (`ptr addrspace(1)`
//! operands of AIR texture operations, also through helper-function arguments, exactly as the emitter's own
//! opaque-resource analysis finds them) or samplers (`ptr addrspace(2)` sampler operands). The
//! load then produces the handle directly, under the first `inttoptr`'s name; further `inttoptr`s of the same integer
//! are renamed to it. The load dominates every `inttoptr` of its result, so the handle dominates every former use.
//! Anything else (a handle integer that is also compared or stored, a volatile or atomic load, an integer that is not
//! a load) is left as written.

use crate::fxhash::{HashMap, HashSet};
use std::borrow::Cow;

struct Conversion {
    line: usize,
    result: String,
    integer: String,
    addrspace: u32,
}

pub(super) fn fold_texture_handle_loads(san_ll: &str) -> Cow<'_, str> {
    // every AIR texture operation's name has `_texture` or `_depth` in it; a module without one has no handle to fold
    if !san_ll.contains("= inttoptr i64 ")
        || !(san_ll.contains("_texture") || san_ll.contains("_depth"))
    {
        return Cow::Borrowed(san_ll);
    }
    let lines: Vec<&str> = san_ll.split('\n').collect();
    // cheap text check first: a module with no integer-to-handle conversion needs no parse
    let candidates = lines.iter().any(|line| parse_conversion(line, 0).is_some());
    if !candidates {
        return Cow::Borrowed(san_ll);
    }
    let Ok(module) = super::ir::LlModule::parse(san_ll) else {
        return Cow::Borrowed(san_ll);
    };
    let textures = super::emitter::functions::opaque_resource_pointer_values_by_function(&module);
    let samplers: HashMap<String, HashSet<String>> = module
        .functions
        .iter()
        .map(|function| {
            (
                function.name.clone(),
                super::emitter::functions::sampler_operand_values(function),
            )
        })
        .collect();

    let mut replaced: HashMap<usize, String> = HashMap::default();
    let mut removed: HashSet<usize> = HashSet::default();
    let mut renames: Vec<(usize, usize, Vec<(String, String)>)> = Vec::new();
    let mut index = 0;
    while index < lines.len() {
        let Some(name) = function_name(lines[index]) else {
            index += 1;
            continue;
        };
        let start = index + 1;
        let Some(end) = (start..lines.len()).find(|&i| lines[i].trim_end() == "}") else {
            break;
        };
        index = end + 1;
        let empty = HashSet::default();
        let function_textures = textures.get(name).unwrap_or(&empty);
        let function_samplers = samplers.get(name).unwrap_or(&empty);
        let mut by_integer: HashMap<String, Vec<Conversion>> = HashMap::default();
        for line in start..end {
            if let Some(conversion) = parse_conversion(lines[line], line) {
                by_integer
                    .entry(conversion.integer.clone())
                    .or_default()
                    .push(conversion);
            }
        }
        let mut function_renames = Vec::new();
        let mut integers: Vec<_> = by_integer.into_iter().collect();
        integers.sort_by_key(|(_, conversions)| conversions[0].line);
        for (integer, conversions) in integers {
            let addrspace = conversions[0].addrspace;
            let handles = conversions.iter().all(|conversion| {
                conversion.addrspace == addrspace
                    && match addrspace {
                        1 => function_textures.contains(&conversion.result),
                        2 => function_samplers.contains(&conversion.result),
                        _ => false,
                    }
            });
            if !handles {
                continue;
            }
            let Some(load) = (start..end).find(|&i| defines(lines[i], &integer)) else {
                continue;
            };
            let Some(rewritten) = handle_load(lines[load], &integer, &conversions[0].result, addrspace)
            else {
                continue;
            };
            let uses: usize = (start..end)
                .filter(|&i| i != load)
                .map(|i| count_uses(lines[i], &integer))
                .sum();
            if uses != conversions.len() {
                continue;
            }
            replaced.insert(load, rewritten);
            for conversion in &conversions {
                removed.insert(conversion.line);
            }
            for conversion in &conversions[1..] {
                function_renames.push((conversion.result.clone(), conversions[0].result.clone()));
            }
        }
        if !function_renames.is_empty() {
            renames.push((start, end, function_renames));
        }
    }
    if replaced.is_empty() {
        return Cow::Borrowed(san_ll);
    }
    let mut out = String::with_capacity(san_ll.len());
    let mut first = true;
    for (number, line) in lines.iter().enumerate() {
        if removed.contains(&number) {
            continue;
        }
        if !first {
            out.push('\n');
        }
        first = false;
        let mut text: Cow<'_, str> = match replaced.get(&number) {
            Some(rewritten) => Cow::Owned(rewritten.clone()),
            None => Cow::Borrowed(line),
        };
        for (start, end, function_renames) in &renames {
            if (*start..*end).contains(&number) {
                for (from, to) in function_renames {
                    if count_uses(&text, from) > 0 {
                        text = Cow::Owned(rename_uses(&text, from, to));
                    }
                }
            }
        }
        out.push_str(&text);
    }
    Cow::Owned(out)
}

/// `define ... @name(` -> `name`
fn function_name(line: &str) -> Option<&str> {
    if !line.starts_with("define ") {
        return None;
    }
    let at = line.find(" @")? + 2;
    let rest = &line[at..];
    let name = &rest[..rest.find('(')?];
    Some(name.trim_matches('"'))
}

/// `  %t = inttoptr i64 %h to ptr addrspace(K)` (K = 1 or 2)
fn parse_conversion(line: &str, number: usize) -> Option<Conversion> {
    let (lhs, rhs) = line.split_once(" = inttoptr i64 ")?;
    let result = lhs.trim();
    if !is_local(result) {
        return None;
    }
    let (integer, ty) = rhs.split_once(" to ")?;
    let integer = integer.trim();
    if !is_local(integer) {
        return None;
    }
    let ty = ty.split(", !").next()?.trim();
    let addrspace = match ty {
        "ptr addrspace(1)" => 1,
        "ptr addrspace(2)" => 2,
        _ => return None,
    };
    Some(Conversion {
        line: number,
        result: result.to_string(),
        integer: integer.to_string(),
        addrspace,
    })
}

fn is_local(name: &str) -> bool {
    name.len() > 1
        && name.starts_with('%')
        && name[1..].bytes().all(is_name_byte)
}

fn is_name_byte(byte: u8) -> bool {
    byte.is_ascii_alphanumeric() || matches!(byte, b'_' | b'.' | b'$' | b'-')
}

fn defines(line: &str, name: &str) -> bool {
    line.trim_start()
        .strip_prefix(name)
        .is_some_and(|rest| rest.starts_with(" = "))
}

/// `%h = load i64, <pointer operand>, <rest>` -> `%t = load ptr addrspace(K), <pointer operand>, <rest>`; a volatile
/// or atomic load keeps its integer form
fn handle_load(line: &str, integer: &str, handle: &str, addrspace: u32) -> Option<String> {
    let indent = &line[..line.len() - line.trim_start().len()];
    let rest = line
        .trim_start()
        .strip_prefix(integer)?
        .strip_prefix(" = load i64, ")?;
    Some(format!(
        "{indent}{handle} = load ptr addrspace({addrspace}), {rest}"
    ))
}

/// occurrences of the local `name` as a whole token (`%9` in `%9,` but not in `%90`)
fn count_uses(line: &str, name: &str) -> usize {
    token_positions(line, name).count()
}

fn rename_uses(line: &str, from: &str, to: &str) -> String {
    let mut out = String::with_capacity(line.len());
    let mut last = 0;
    for at in token_positions(line, from) {
        out.push_str(&line[last..at]);
        out.push_str(to);
        last = at + from.len();
    }
    out.push_str(&line[last..]);
    out
}

fn token_positions<'a>(line: &'a str, name: &'a str) -> impl Iterator<Item = usize> + 'a {
    line.match_indices(name).filter_map(move |(at, _)| {
        let after = line.as_bytes().get(at + name.len());
        (!after.is_some_and(|&byte| is_name_byte(byte))).then_some(at)
    })
}

#[cfg(test)]
mod tests {
    use super::fold_texture_handle_loads;

    const DECLS: &str = r#"
declare { <4 x float>, i8 } @air.read_texture_2d.v4f32(ptr addrspace(1), ptr addrspace(2), <2 x i32>, <2 x i32>, i32, i32)
declare <4 x float> @air.sample_texture_2d.v4f32(ptr addrspace(1), ptr addrspace(2), <2 x float>, i1, <2 x i32>, i1, float, float, i32)
declare ptr addrspace(2) @air.get_read_sampler()
declare i32 @air.get_width_texture_2d(ptr addrspace(1), i32)
declare void @air.discard_fragment()
"#;

    fn module(body: &str) -> String {
        format!("{body}\n{DECLS}")
    }

    #[test]
    fn a_resource_id_used_in_two_blocks_becomes_one_handle_load() {
        let src = module(
            r#"define i32 @f(ptr addrspace(2) %ab, <2 x i32> %c, i1 %cond) {
entry:
  %field = getelementptr inbounds { i64, i64 }, ptr addrspace(2) %ab, i64 0, i32 1
  %9 = load i64, ptr addrspace(2) %field, align 8, !alias.scope !4
  %90 = add i32 0, 1
  %t = inttoptr i64 %9 to ptr addrspace(1)
  %s = call ptr addrspace(2) @air.get_read_sampler()
  %r = call { <4 x float>, i8 } @air.read_texture_2d.v4f32(ptr addrspace(1) %t, ptr addrspace(2) %s, <2 x i32> %c, <2 x i32> zeroinitializer, i32 0, i32 0)
  br i1 %cond, label %then, label %join
then:
  call void @air.discard_fragment()
  br label %join
join:
  %w = call i32 @air.get_width_texture_2d(ptr addrspace(1) %t, i32 0)
  ret i32 %w
}"#,
        );
        let out = fold_texture_handle_loads(&src);
        assert!(
            out.contains("  %t = load ptr addrspace(1), ptr addrspace(2) %field, align 8, !alias.scope !4\n"),
            "{out}"
        );
        assert!(!out.contains("inttoptr"), "{out}");
        assert!(out.contains("  %90 = add i32 0, 1\n"), "{out}");
    }

    #[test]
    fn two_conversions_of_one_integer_share_the_handle() {
        let src = module(
            r#"define <4 x float> @f(ptr addrspace(2) %ab, <2 x float> %uv, i1 %cond) {
entry:
  %h = load i64, ptr addrspace(2) %ab, align 8
  %s = call ptr addrspace(2) @air.get_read_sampler()
  br i1 %cond, label %a, label %b
a:
  %ta = inttoptr i64 %h to ptr addrspace(1)
  %va = call <4 x float> @air.sample_texture_2d.v4f32(ptr addrspace(1) %ta, ptr addrspace(2) %s, <2 x float> %uv, i1 true, <2 x i32> zeroinitializer, i1 false, float 0.0, float 0.0, i32 0)
  br label %join
b:
  %tb = inttoptr i64 %h to ptr addrspace(1)
  %vb = call <4 x float> @air.sample_texture_2d.v4f32(ptr addrspace(1) %tb, ptr addrspace(2) %s, <2 x float> %uv, i1 true, <2 x i32> zeroinitializer, i1 false, float 0.0, float 0.0, i32 0)
  br label %join
join:
  %v = phi <4 x float> [ %va, %a ], [ %vb, %b ]
  ret <4 x float> %v
}"#,
        );
        let out = fold_texture_handle_loads(&src);
        assert!(out.contains("  %ta = load ptr addrspace(1), ptr addrspace(2) %ab, align 8\n"), "{out}");
        assert!(out.contains("(ptr addrspace(1) %ta, ptr addrspace(2) %s, <2 x float> %uv"), "{out}");
        assert!(!out.contains("%tb"), "{out}");
        assert!(!out.contains("inttoptr"), "{out}");
    }

    #[test]
    fn a_sampler_resource_id_becomes_a_sampler_load() {
        let src = module(
            r#"define <4 x float> @f(ptr addrspace(1) %tex, ptr addrspace(2) %ab, <2 x float> %uv) {
entry:
  %h = load i64, ptr addrspace(2) %ab, align 8
  %s = inttoptr i64 %h to ptr addrspace(2)
  %v = call <4 x float> @air.sample_texture_2d.v4f32(ptr addrspace(1) %tex, ptr addrspace(2) %s, <2 x float> %uv, i1 true, <2 x i32> zeroinitializer, i1 false, float 0.0, float 0.0, i32 0)
  ret <4 x float> %v
}"#,
        );
        let out = fold_texture_handle_loads(&src);
        assert!(out.contains("  %s = load ptr addrspace(2), ptr addrspace(2) %ab, align 8\n"), "{out}");
        assert!(!out.contains("inttoptr"), "{out}");
    }

    #[test]
    fn an_integer_with_another_use_or_a_memory_pointer_is_left_alone() {
        // the handle integer is also compared: the conversion stays
        let compared = module(
            r#"define i32 @f(ptr addrspace(2) %ab) {
entry:
  %h = load i64, ptr addrspace(2) %ab, align 8
  %null = icmp eq i64 %h, 0
  %t = inttoptr i64 %h to ptr addrspace(1)
  %w = call i32 @air.get_width_texture_2d(ptr addrspace(1) %t, i32 0)
  %r = select i1 %null, i32 0, i32 %w
  ret i32 %r
}"#,
        );
        assert_eq!(fold_texture_handle_loads(&compared), compared);
        // a device address is memory, not a resource
        let memory = module(
            r#"define i32 @f(ptr addrspace(2) %ab) {
entry:
  %h = load i64, ptr addrspace(2) %ab, align 8
  %p = inttoptr i64 %h to ptr addrspace(1)
  %v = load i32, ptr addrspace(1) %p, align 4
  ret i32 %v
}"#,
        );
        assert_eq!(fold_texture_handle_loads(&memory), memory);
        // a volatile load keeps its integer form
        let volatile = module(
            r#"define i32 @f(ptr addrspace(2) %ab) {
entry:
  %h = load volatile i64, ptr addrspace(2) %ab, align 8
  %t = inttoptr i64 %h to ptr addrspace(1)
  %w = call i32 @air.get_width_texture_2d(ptr addrspace(1) %t, i32 0)
  ret i32 %w
}"#,
        );
        assert_eq!(fold_texture_handle_loads(&volatile), volatile);
    }
}
