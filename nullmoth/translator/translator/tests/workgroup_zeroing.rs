//! Workgroup memory zeroed the ways Metal shaders do it.
//!
//! A threadgroup parameter zeroed whole (`threadgroup S &s [[threadgroup(0)]]`, `s = S{}`), as WebKit zero-initialises a
//! WGSL `var<workgroup>`.
//!
//! The parameter becomes a Workgroup array whose element is the layout type the kernel metadata describes, and the
//! `llvm.memset` of the whole S is emitted as a Store of S's null straight through the parameter. When S was not on the
//! array's member-0 path (a different id of the same shape), nothing routed that Store to element 0 and the module broke
//! the Store contract, so the kernel was refused: in Safari on the B580 every WGSL compute shader with a workgroup
//! variable failed createComputePipeline (tools/regress/pages/sweep.html).
use metal2vulkan::passes::{Stage, TransformOptions};
use metal2vulkan::{disassemble, translate_native_no_retry_constructed_with_options};

const ZEROED: &str = include_str!("fixtures/webgpu/threadgroup_struct_param_zeroed.ll");
const BYTEWISE: &str = include_str!("fixtures/webgpu/workgroup_zeroed_bytewise.ll");

fn spirv_val(spv: &[u8], name: &str) {
    if std::process::Command::new("spirv-val").arg("--version").output().is_err() {
        return;
    }
    let p = std::env::temp_dir().join(format!("m2v_{name}_{}.spv", std::process::id()));
    std::fs::write(&p, spv).unwrap();
    let out = std::process::Command::new("spirv-val").args(["--target-env", "vulkan1.2"]).arg(&p).output().unwrap();
    assert!(out.status.success(), "spirv-val: {}{}", String::from_utf8_lossy(&out.stdout), String::from_utf8_lossy(&out.stderr));
}

/// WebKit's `__wgslZeroWorkgroupVar`: a byte loop storing 0 through a uchar pointer into each u32 word of a
/// `var<workgroup> array<u32, 64>`. Each byte store is a read-modify-write of its word (passes/access/workgroup_bytes.rs).
#[test]
fn webkit_bytewise_workgroup_zeroing_translates_as_word_read_modify_write() {
    let spv = translate_native_no_retry_constructed_with_options(BYTEWISE, Stage::Kernel, TransformOptions::default())
        .expect("WebKit's workgroup zeroing must translate");
    spirv_val(&spv, "wg_bytewise");
    let asm = disassemble(&spv).expect("disassemble");
    assert!(!asm.contains("_ptr_Workgroup_uchar"), "no byte pointer into Workgroup memory remains\n{asm}");
    assert!(asm.contains("OpNot"), "the byte's mask\n{asm}");
    assert!(asm.contains("OpBitwiseOr"), "the merged word\n{asm}");
}

#[test]
fn a_threadgroup_struct_parameter_zeroed_whole_translates() {
    let tmp = std::env::temp_dir().join(format!("m2v_tg_zeroed_{}", std::process::id()));
    let _ = std::fs::create_dir_all(&tmp);
    // the plugin's path (nvmtl_translate): the native construction on the AIR text as Metal's compiler wrote it
    let spv = translate_native_no_retry_constructed_with_options(ZEROED, Stage::Kernel, TransformOptions::default())
        .expect("the zeroed threadgroup struct must translate");
    let asm = disassemble(&spv).expect("disassemble");
    assert!(asm.contains("Workgroup"), "{asm}");
    // the zero is stored through element 0 of the Workgroup array, as the element type's null
    let store = asm.lines().find(|l| l.contains("OpStore") && {
        let v = l.split_whitespace().last().unwrap();
        asm.lines().any(|d| d.trim_start().starts_with(&format!("{v} = OpConstantNull")))
    });
    assert!(store.is_some(), "no null store\n{asm}");
    if std::process::Command::new("spirv-val").arg("--version").output().is_ok() {
        let p = tmp.join("tg_zeroed.spv");
        std::fs::write(&p, &spv).unwrap();
        let out = std::process::Command::new("spirv-val").args(["--target-env", "vulkan1.2"]).arg(&p).output().unwrap();
        assert!(out.status.success(), "spirv-val: {}{}", String::from_utf8_lossy(&out.stdout), String::from_utf8_lossy(&out.stderr));
    }
}
