//! A buffer pointer held in an argument buffer is a device address, whichever construction reads the argument buffer.
//!
//! WebKit (Safari's WebGPU) puts a bind group's sampler, its texture (as a 64-bit resource ID) and a pointer to its
//! uniform struct into one argument buffer. The plugin's first translation refuses the sampler ("sampler operand is not
//! a sampler"); its retry reads argument-buffer samplers from the sampler heap and builds the buffers raw first. That raw
//! construction never took the device-address model, so the uniform pointer loaded out of the argument buffer was an
//! unmodeled placeholder and the `load <2 x float>` through it became `OpCopyObject` of `OpConstantNull`: three.js'
//! `textureSample(tex, smp, fragCoord.xy / u)` divided by zero and every WebGPU example drew only its background.
//! The raw construction now reads the field's device address as the primary one does, and a read through a pointer
//! the emitter cannot model is refused instead of becoming a zero.
use metal2vulkan::passes::{Stage, TransformOptions};
use metal2vulkan::{disassemble, translate_native_no_retry_constructed_with_options, with_argument_buffer_samplers};

const UNIFORM_POINTER: &str = include_str!("fixtures/webgpu/argument_buffer_uniform_pointer.ll");

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

/// No value of the module is a copy of a null constant.
fn assert_no_null_copies(asm: &str) {
    for line in asm.lines().filter(|line| line.contains("OpCopyObject")) {
        let source = line.split_whitespace().last().unwrap();
        assert_ne!(def(asm, source).0, "OpConstantNull", "a load folded to a null constant: {line}\n{asm}");
    }
}

/// The divisor of the shader's one `OpFDiv` is read from memory through a device address: a load, or the call of the
/// null-guarded device-address load helper.
fn assert_divisor_read_from_memory(asm: &str) {
    let divs: Vec<_> = asm.lines().filter(|line| line.contains("OpFDiv")).collect();
    assert_eq!(divs.len(), 1, "{asm}");
    let divisor = divs[0].split_whitespace().last().unwrap();
    let (op, _) = def(asm, divisor);
    assert!(matches!(op, "OpLoad" | "OpFunctionCall"), "the divisor {divisor} is {op}, not a read\n{asm}");
    assert!(asm.contains("OpConvertUToPtr"), "the uniform is read through its device address\n{asm}");
    assert!(asm.contains("PhysicalStorageBuffer"), "{asm}");
}

#[test]
fn a_uniform_pointer_beside_a_resource_id_texture_is_read_in_the_plugins_retry() {
    // the plugin's retry (nvmtl_translate's translate_with_pointer_retry): argument-buffer samplers, raw buffers first
    let spv = with_argument_buffer_samplers(|| {
        translate_native_no_retry_constructed_with_options(UNIFORM_POINTER, Stage::Fragment, TransformOptions::default())
    })
    .expect("the WebGPU fragment shader must translate");
    spirv_val(&spv);
    let asm = disassemble(&spv).expect("disassemble");
    assert_no_null_copies(&asm);
    assert_divisor_read_from_memory(&asm);
    assert!(asm.contains("OpImageSampleImplicitLod"), "{asm}");
}

#[test]
fn the_raw_construction_reads_an_argument_buffer_pointer_field_by_its_device_address() {
    // the raw construction alone; it emitted the null copy before it took the device-address model. It takes lowered
    // AIR, where the texture is already the handle load Metal's compiler writes (texture_handle_loads).
    let lowered = UNIFORM_POINTER
        .replace(
            "%texture.id = load i64, ptr addrspace(2) %texture.field, align 8",
            "%texture = load ptr addrspace(1), ptr addrspace(2) %texture.field, align 8",
        )
        .replace("  %texture = inttoptr i64 %texture.id to ptr addrspace(1)\n", "");
    assert!(!lowered.contains("= inttoptr"), "{lowered}");
    let spv = with_argument_buffer_samplers(|| {
        metal2vulkan::tools::emit_vulkan_spirv_all_buffers_raw(&lowered, std::path::Path::new(""))
    })
    .expect("the raw construction must emit the shader");
    let asm = disassemble(&spv).expect("disassemble");
    assert_no_null_copies(&asm);
    assert!(asm.contains("OpConvertUToPtr"), "the uniform is read through its device address\n{asm}");
}

#[test]
fn a_read_through_an_unmodeled_pointer_is_refused_not_zero() {
    let error = translate_native_no_retry_constructed_with_options(
        include_str!("fixtures/unmodeled_pointer/copied_pointer_table.ll"),
        Stage::Kernel,
        TransformOptions::default(),
    )
    .expect_err("a read through a pointer the emitter cannot model must fail, not read zero");
    assert!(error.contains("unmodeled pointer placeholder"), "{error}");
    assert!(error.contains("load %value through %row"), "{error}");
}
