//! WebKit's WGSL compiler (Safari's WebGPU) puts each texture of a bind group into an argument buffer as its 64-bit
//! resource ID and reads it back as an integer: `%id = load i64, ptr addrspace(2) %field` then
//! `%texture = inttoptr i64 %id to ptr addrspace(1)`, where Metal's own compiler loads the handle as a pointer. The
//! translator knew only the pointer form. Under the device-address model (taken here because the second argument
//! buffer holds a constant-buffer pointer) the conversion defined no value, so the texture's use after the
//! `discard_fragment` branch failed: "native emitter: unknown SSA value %9" in the webgpu-samples deferredRendering
//! lighting pass ("Fragment function failed creation"). Without that model the conversion made an unmodeled (null)
//! pointer: the shader translated, but its texture reads were zero and its size queries 0 (the same sample's G-buffer
//! view). Both now load the handle as Metal's compiler does.
use metal2vulkan::passes::{Stage, TransformOptions};
use metal2vulkan::{disassemble, translate_native_no_retry_constructed_with_options};

fn spirv_val(spv: &[u8]) {
    let out = std::process::Command::new("spirv-val").args(["--target-env", "vulkan1.2", "-"]).stdin(std::process::Stdio::piped())
        .stdout(std::process::Stdio::piped()).stderr(std::process::Stdio::piped()).spawn().and_then(|mut c| {
            use std::io::Write; c.stdin.take().unwrap().write_all(spv)?; c.wait_with_output() });
    if let Ok(out) = out { assert!(out.status.success(), "spirv-val: {}{}", String::from_utf8_lossy(&out.stdout), String::from_utf8_lossy(&out.stderr)); }
}

fn translate(ll: &str) -> String {
    // the plugin's first attempt (as written, no retry)
    let spv = translate_native_no_retry_constructed_with_options(ll, Stage::Fragment, TransformOptions::default())
        .expect("a texture read by its resource ID must translate");
    spirv_val(&spv);
    disassemble(&spv).expect("disassemble")
}

fn count(asm: &str, op: &str) -> usize {
    asm.lines().filter(|line| line.contains(op)).count()
}

#[test]
fn a_resource_id_texture_used_after_a_discard_branch_translates() {
    let asm = translate(include_str!("fixtures/webgpu/resource_id_texture_after_discard.ll"));
    // the read in the entry block and both size queries after the branch use the texture
    assert_eq!(count(&asm, "OpImageFetch"), 1, "{asm}");
    assert_eq!(count(&asm, "OpImageQuerySizeLod"), 2, "{asm}");
}

#[test]
fn resource_id_textures_in_a_bound_argument_buffer_are_read() {
    let asm = translate(include_str!("fixtures/webgpu/resource_id_textures_bound_buffer.ll"));
    // two reads and a size query, none folded to a null texture
    assert_eq!(count(&asm, "OpImageFetch"), 2, "{asm}");
    assert_eq!(count(&asm, "OpImageQuerySizeLod"), 1, "{asm}");
}
