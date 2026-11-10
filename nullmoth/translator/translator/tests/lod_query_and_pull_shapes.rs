//! `calculate_clamped_lod` / `calculate_unclamped_lod` on every texture shape Metal allows (2D array, 3D, cube, cube
//! array, and the depth forms), and pull-model interpolation (`interpolant<T>`: at the centre, at an offset, at a sample,
//! at the centroid) including half-precision interpolants. The fixtures are the AIR Apple's compiler (Metal 4, AIR 2.9)
//! made of `fixtures/lod_pull/probe.metal`. Before this, every LOD query but the 2D one was "unrecognized AIR intrinsic
//! family", and any fragment function with a half interpolant was refused.
use metal2vulkan::passes::Stage;
use metal2vulkan::{disassemble, translate_sanitized_native};

fn tmp() -> std::path::PathBuf {
    let d = std::env::temp_dir().join(format!("m2v_lod_pull_{}", std::process::id()));
    let _ = std::fs::create_dir_all(&d);
    d
}

fn spirv_val(spv: &[u8]) {
    let out = std::process::Command::new("spirv-val")
        .args(["--target-env", "vulkan1.2", "-"])
        .stdin(std::process::Stdio::piped())
        .stdout(std::process::Stdio::piped())
        .stderr(std::process::Stdio::piped())
        .spawn()
        .and_then(|mut c| {
            use std::io::Write;
            c.stdin.take().unwrap().write_all(spv)?;
            c.wait_with_output()
        });
    if let Ok(out) = out {
        assert!(out.status.success(), "spirv-val: {}{}", String::from_utf8_lossy(&out.stdout), String::from_utf8_lossy(&out.stderr));
    }
}

fn translate(ll: &str) -> String {
    let spv = translate_sanitized_native(ll, Stage::Fragment, &tmp()).unwrap_or_else(|e| panic!("must translate: {e}"));
    spirv_val(&spv);
    disassemble(&spv).expect("disassemble")
}

/// One OpImageQueryLod per call, the clamped one reading component 0 and the unclamped one component 1, on an image of
/// the expected dimensionality and arrayedness (`OpTypeImage %float <dim> <depth> <arrayed> ...`).
fn assert_lod_queries(asm: &str, calls: usize, dim: &str, arrayed: bool) {
    assert_eq!(asm.matches("OpImageQueryLod").count(), calls, "{asm}");
    assert!(asm.contains("OpCapability ImageQuery"), "{asm}");
    // `%n = OpTypeImage %sampled <Dim> <Depth> <Arrayed> ...`: the one sampled image the probe declares
    let image = asm.lines().find(|l| l.contains("OpTypeImage")).unwrap_or_else(|| panic!("no image type:\n{asm}"));
    let fields: Vec<&str> = image.split_whitespace().collect();
    let at = fields.iter().position(|f| *f == "OpTypeImage").unwrap();
    assert_eq!(fields[at + 2], dim, "{image}");
    assert_eq!(fields[at + 4], if arrayed { "1" } else { "0" }, "{image}");
}

#[test]
fn lod_queries_on_2d_arrays_3d_and_cubes() {
    for (ll, dim, arrayed) in [
        (include_str!("fixtures/lod_pull/lod_2da.ll"), "2D", true),
        (include_str!("fixtures/lod_pull/lod_3d.ll"), "3D", false),
        (include_str!("fixtures/lod_pull/lod_cube.ll"), "Cube", false),
        (include_str!("fixtures/lod_pull/lod_cubea.ll"), "Cube", true),
    ] {
        assert_lod_queries(&translate(ll), 2, dim, arrayed);
    }
}

#[test]
fn lod_queries_on_depth_textures() {
    for (ll, dim, arrayed) in [
        (include_str!("fixtures/lod_pull/lod_d2d.ll"), "2D", false),
        (include_str!("fixtures/lod_pull/lod_d2da.ll"), "2D", true),
        (include_str!("fixtures/lod_pull/lod_dcube.ll"), "Cube", false),
        (include_str!("fixtures/lod_pull/lod_dcubea.ll"), "Cube", true),
    ] {
        assert_lod_queries(&translate(ll), 2, dim, arrayed);
    }
}

#[test]
fn a_cube_lod_query_through_a_constexpr_sampler() {
    assert_lod_queries(&translate(include_str!("fixtures/lod_pull/lod_cube_const.ll")), 1, "Cube", false);
}

#[test]
fn pull_model_interpolation_at_every_point_with_a_half_interpolant() {
    for (ll, op, n) in [
        (include_str!("fixtures/lod_pull/pull_center.ll"), "InterpolateAtOffset", 4),
        (include_str!("fixtures/lod_pull/pull_offset.ll"), "InterpolateAtOffset", 4),
        (include_str!("fixtures/lod_pull/pull_centroid.ll"), "InterpolateAtCentroid", 4),
        (include_str!("fixtures/lod_pull/pull_sample.ll"), "InterpolateAtSample", 4),
        (include_str!("fixtures/lod_pull/pull_sample_k.ll"), "InterpolateAtSample", 1),
    ] {
        let asm = translate(ll);
        assert_eq!(asm.matches(op).count(), n, "{asm}");
        assert!(asm.contains("OpCapability InterpolationFunction"), "{asm}");
        if ll.contains("interpolate_offset_") {
            // Metal's offset counts from the pixel's upper-left corner, SPIR-V's from its centre: 0.5 is taken off
            assert!(asm.contains("OpFSub"), "{asm}");
        }
        if n == 4 {
            // the half3 interpolant is interpolated at 32 bits (its varying travels as float3) and converted
            assert!(asm.contains("OpTypeFloat 16") && asm.contains("OpFConvert"), "{asm}");
        }
    }
}
