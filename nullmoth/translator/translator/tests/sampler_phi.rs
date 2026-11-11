//! Samplers merged by a `phi` or `select` (two samplers of one WebKit-style argument buffer, the fragment's position
//! chooses). With argument-buffer samplers (the plugin's retry, crate::with_argument_buffer_samplers) a sampler read from
//! an argument buffer is a sampler-heap slot; the merged sampler must read the chosen slot: an OpSelect / OpPhi of the
//! two slots feeding the heap access, not a fallback to a bound sampler and not a refusal.
use metal2vulkan::passes::{Stage, TransformOptions};
use metal2vulkan::{disassemble, translate_native_no_retry_constructed_with_options, with_argument_buffer_samplers};

const SELECT: &str = include_str!("fixtures/sampler_phi/select_load.ll");
const PHI: &str = include_str!("fixtures/sampler_phi/phi_load.ll");

fn spirv_val(spv: &[u8]) {
    let out = std::process::Command::new("spirv-val").args(["--target-env", "vulkan1.3", "-"]).stdin(std::process::Stdio::piped())
        .stdout(std::process::Stdio::piped()).stderr(std::process::Stdio::piped()).spawn().and_then(|mut c| {
            use std::io::Write; c.stdin.take().unwrap().write_all(spv)?; c.wait_with_output() });
    if let Ok(out) = out { assert!(out.status.success(), "spirv-val: {}{}", String::from_utf8_lossy(&out.stdout), String::from_utf8_lossy(&out.stderr)); }
}

/// The instruction defining `%id`, as its opcode and operands.
fn def<'a>(asm: &'a str, id: &str) -> (&'a str, Vec<&'a str>) {
    let prefix = format!("{id} = ");
    let line = asm.lines().find(|line| line.trim_start().starts_with(&prefix)).unwrap_or_else(|| panic!("{id} undefined\n{asm}"));
    let mut words = line.trim_start()[prefix.len()..].split_whitespace();
    (words.next().unwrap(), words.collect())
}

/// The sampler of the one sampled-image construction is loaded from the sampler heap at an index that depends on an
/// instruction `merge` (OpSelect or OpPhi) choosing between two different values: the slot is read from the chosen
/// argument-buffer field (its resource ID's low word), so the merge picks the field.
fn assert_sampler_from_merged_slot(asm: &str, merge: &str) {
    let combine: Vec<_> = asm.lines().filter(|line| line.contains("OpSampledImage")).collect();
    assert_eq!(combine.len(), 1, "{asm}");
    let sampler = combine[0].split_whitespace().last().unwrap();
    let (op, ops) = def(asm, sampler);
    assert_eq!(op, "OpLoad", "the sampler {sampler} is {op}, not loaded from the heap\n{asm}");
    let (chain_op, chain) = def(asm, ops[1]);
    assert!(chain_op.ends_with("AccessChain"), "the sampler is loaded through {chain_op}\n{asm}");
    // walk back from the heap index through arithmetic, loads and access chains to the merge
    let mut todo = vec![(*chain.last().unwrap(), 0)];
    let mut seen = std::collections::HashSet::new();
    while let Some((id, depth)) = todo.pop() {
        if depth > 16 || !id.starts_with('%') || !seen.insert(id) {
            continue;
        }
        let Some(line) = asm.lines().find(|line| line.trim_start().starts_with(&format!("{id} = "))) else { continue };
        let (op, ops) = def(asm, id);
        if op == merge {
            let values: Vec<_> = if merge == "OpSelect" { ops[2..4].to_vec() } else { ops[1..].iter().step_by(2).copied().collect() };
            assert!(values.len() == 2 && values[0] != values[1], "the merge {id} does not choose between two values\n{line}\n{asm}");
            return;
        }
        if matches!(op, "OpConstant" | "OpVariable" | "OpFunctionParameter") {
            continue;
        }
        todo.extend(ops.iter().skip(1).map(|o| (*o, depth + 1)));
    }
    panic!("no {merge} behind the sampler-heap index\n{asm}");
}

fn translate(ll: &str) -> String {
    let spv = with_argument_buffer_samplers(|| {
        translate_native_no_retry_constructed_with_options(ll, Stage::Fragment, TransformOptions::default())
    })
    .expect("the shader must translate");
    spirv_val(&spv);
    disassemble(&spv).expect("disassemble")
}

#[test]
fn samplers_merged_by_a_select_read_the_chosen_heap_slot() {
    assert_sampler_from_merged_slot(&translate(SELECT), "OpSelect");
}

#[test]
fn samplers_merged_by_a_phi_read_the_chosen_heap_slot() {
    assert_sampler_from_merged_slot(&translate(PHI), "OpPhi");
}
