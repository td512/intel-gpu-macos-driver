//! Two argument-buffer textures merged by a `phi` or a `select` before a texture operation
//! (`%t = phi ptr addrspace(1) [ %albedo, %a ], [ %depth, %b ]`). Each handle alone is read from the bindless heap by
//! the slot its argument-buffer field holds; the merged handle had no slot, so the read fell back to another image the
//! entry bound (here the buffer's unused first texture) or read zero. The merge now selects between the heap slots,
//! for Metal's own pointer load and for WebKit's `load i64` + `inttoptr` form alike.
use metal2vulkan::passes::{Stage, TransformOptions};
use metal2vulkan::{disassemble, translate_native_no_retry_constructed_with_options};

fn spirv_val(spv: &[u8]) {
    let out = std::process::Command::new("spirv-val").args(["--target-env", "vulkan1.3", "-"]).stdin(std::process::Stdio::piped())
        .stdout(std::process::Stdio::piped()).stderr(std::process::Stdio::piped()).spawn().and_then(|mut c| {
            use std::io::Write; c.stdin.take().unwrap().write_all(spv)?; c.wait_with_output() });
    if let Ok(out) = out { assert!(out.status.success(), "spirv-val: {}{}", String::from_utf8_lossy(&out.stdout), String::from_utf8_lossy(&out.stderr)); }
}

fn translate(ll: &str) -> String {
    let spv = translate_native_no_retry_constructed_with_options(ll, Stage::Fragment, TransformOptions::default())
        .expect("merged argument-buffer textures must translate");
    spirv_val(&spv);
    disassemble(&spv).expect("disassemble")
}

/// The instruction defining `%id`, as its opcode and operands.
fn def<'a>(asm: &'a str, id: &str) -> (&'a str, Vec<&'a str>) {
    let prefix = format!("{id} = ");
    let line = asm.lines().find(|line| line.trim_start().starts_with(&prefix)).unwrap_or_else(|| panic!("{id} undefined\n{asm}"));
    let mut words = line.trim_start()[prefix.len()..].split_whitespace();
    (words.next().unwrap(), words.collect())
}

/// The single texel fetch reads `heap[slot]` where the slot is merged by `merge` (OpPhi or OpSelect).
fn assert_reads_merged_heap_slot(asm: &str, merge: &str) {
    let fetches: Vec<_> = asm.lines().filter(|line| line.contains("OpImageFetch")).collect();
    assert_eq!(fetches.len(), 1, "{asm}");
    let image = fetches[0].split_whitespace().nth(4).unwrap();
    let (op, operands) = def(asm, image);
    assert_eq!(op, "OpLoad", "the fetched image is loaded\n{asm}");
    let (op, chain) = def(asm, operands[1]);
    assert_eq!(op, "OpAccessChain", "the image comes from the heap\n{asm}");
    assert_eq!(def(asm, chain[1]).0, "OpVariable", "{asm}");
    let (op, slots) = def(asm, chain[2]);
    assert_eq!(op, merge, "the heap index is the merge of both slots\n{asm}");
    // the incoming slots are two different argument-buffer fields, each masked to a heap slot
    let incoming = if merge == "OpPhi" { [slots[1], slots[3]] } else { [slots[2], slots[3]] };
    let words: Vec<_> = incoming
        .iter()
        .map(|slot| {
            let (op, operands) = def(asm, slot);
            assert_eq!(op, "OpBitwiseAnd", "{asm}");
            operands[1]
        })
        .collect();
    assert_ne!(words[0], words[1], "{asm}");
    assert!(!asm.contains("OpConstantNull %22"), "{asm}");
}

#[test]
fn a_phi_of_argument_buffer_textures_reads_the_chosen_heap_slot() {
    assert_reads_merged_heap_slot(&translate(include_str!("fixtures/texhandle_phi/phi_load.ll")), "OpPhi");
}

#[test]
fn a_phi_of_resource_id_textures_reads_the_chosen_heap_slot() {
    assert_reads_merged_heap_slot(&translate(include_str!("fixtures/texhandle_phi/phi_inttoptr.ll")), "OpPhi");
}

#[test]
fn a_select_of_argument_buffer_textures_reads_the_chosen_heap_slot() {
    assert_reads_merged_heap_slot(&translate(include_str!("fixtures/texhandle_phi/select_load.ll")), "OpSelect");
}
