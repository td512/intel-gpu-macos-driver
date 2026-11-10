use metal2vulkan::meta::{TextureComponent, TextureDimension, TextureShape};
use metal2vulkan::passes::{Stage, TransformOptions};
use metal2vulkan::reflect::ShaderReflection;
use std::collections::HashMap;
use std::path::{Path, PathBuf};

const CUBE_TEXEL_COPY: &str = r#"target triple = "spirv-unknown-vulkan1.2"

define void @copy_cube_face(ptr addrspace(1) %src, ptr addrspace(1) %dst, <2 x i32> %coord, i32 %face) {
entry:
  %sampler = tail call ptr addrspace(2) @air.get_read_sampler()
  %read = tail call { <4 x float>, i8 } @air.read_texture_cube.v4f32(ptr addrspace(1) %src, ptr addrspace(2) %sampler, <2 x i32> %coord, i32 %face, i32 0, i32 1)
  %texel = extractvalue { <4 x float>, i8 } %read, 0
  tail call void @air.write_texture_cube.v4f32(ptr addrspace(1) %dst, <2 x i32> %coord, i32 %face, <4 x float> %texel, i32 0, i32 2)
  ret void
}

declare ptr addrspace(2) @air.get_read_sampler()
declare { <4 x float>, i8 } @air.read_texture_cube.v4f32(ptr addrspace(1), ptr addrspace(2), <2 x i32>, i32, i32, i32)
declare void @air.write_texture_cube.v4f32(ptr addrspace(1), <2 x i32>, i32, <4 x float>, i32, i32)

!air.kernel = !{!0}
!0 = !{ptr @copy_cube_face, !1, !2}
!1 = !{}
!2 = !{!3, !4, !5, !6}
!3 = !{i32 0, !"air.texture", !"air.location_index", i32 0, i32 1, !"air.read", !"air.arg_type_name", !"texturecube<float, read>", !"air.arg_name", !"src"}
!4 = !{i32 1, !"air.texture", !"air.location_index", i32 1, i32 1, !"air.write", !"air.arg_type_name", !"texturecube<float, write>", !"air.arg_name", !"dst"}
!5 = !{i32 2, !"air.thread_position_in_grid", !"air.arg_type_name", !"uint2", !"air.arg_name", !"coord"}
!6 = !{i32 3, !"air.threadgroup_position_in_grid", !"air.arg_type_name", !"uint", !"air.arg_name", !"face"}
"#;

const TEXTURE_SHAPE_GRAMMAR: &str = r#"target triple = "spirv-unknown-vulkan1.2"

define void @probe(ptr addrspace(1) %a, ptr addrspace(1) %b, ptr addrspace(1) %c, ptr addrspace(1) %d, ptr addrspace(1) %out) {
entry:
  %w0 = call i32 @air.get_width_texture_2d_array(ptr addrspace(1) %a, i32 0)
  %w1 = call i32 @air.get_width_texture_3d(ptr addrspace(1) %b, i32 0)
  %w2 = call i32 @air.get_width_texture_1d(ptr addrspace(1) %c, i32 0)
  call void @air.write_texture_2d.v4f32(ptr addrspace(1) %d, <2 x i32> zeroinitializer, <4 x float> zeroinitializer, i32 0, i32 2)
  %s0 = add i32 %w0, %w1
  %s1 = add i32 %s0, %w2
  store i32 %s1, ptr addrspace(1) %out, align 4
  ret void
}

declare i32 @air.get_width_texture_2d_array(ptr addrspace(1), i32)
declare i32 @air.get_width_texture_3d(ptr addrspace(1), i32)
declare i32 @air.get_width_texture_1d(ptr addrspace(1), i32)
declare void @air.write_texture_2d.v4f32(ptr addrspace(1), <2 x i32>, <4 x float>, i32, i32)

!air.kernel = !{!0}
!0 = !{ptr @probe, !1, !2}
!1 = !{}
!2 = !{!3, !4, !5, !6, !7}
!3 = !{i32 0, !"air.texture", !"air.location_index", i32 0, i32 1, !"air.sample", !"air.arg_type_name", !"texture2d_array<half, sample>", !"air.arg_name", !"a"}
!4 = !{i32 1, !"air.texture", !"air.location_index", i32 1, i32 1, !"air.read", !"air.arg_type_name", !"texture3d<uint, read>", !"air.arg_name", !"b"}
!5 = !{i32 2, !"air.texture", !"air.location_index", i32 2, i32 1, !"air.read", !"air.arg_type_name", !"texture1d<int, read>", !"air.arg_name", !"c"}
!6 = !{i32 3, !"air.texture", !"air.location_index", i32 3, i32 1, !"air.write", !"air.arg_type_name", !"texture2d<float, write>", !"air.arg_name", !"d"}
!7 = !{i32 4, !"air.buffer", !"air.buffer_size", i32 4, !"air.location_index", i32 0, i32 1, !"air.write", !"air.address_space", i32 1, !"air.arg_type_size", i32 4, !"air.arg_type_align_size", i32 4, !"air.arg_type_name", !"uint", !"air.arg_name", !"out"}
"#;

#[test]
fn every_shape_the_type_name_grammar_produces_matches_its_emitted_image() {
    let (spirv, reflection) = translate(TEXTURE_SHAPE_GRAMMAR, Stage::Kernel, "shape_grammar");
    let checked = assert_shapes_match_the_module("the shape-grammar probe", &spirv, &reflection);
    // Under bindless-all (the default) the three read textures have no binding of their own: each is a slot of the
    // heap of its shape (set 2), so only the written texture's binding has a shape to compare...
    assert_eq!(checked, 1, "the written texture has a binding to check");
    // ...and the heaps the module declares carry the three read shapes.
    let text = metal2vulkan::disassemble(&spirv).expect("disassemble");
    for (shape, what) in [
        ("2D 0 1 0 1", "the sampled 2D array"),
        ("3D 0 0 0 1", "the read 3D texture"),
        ("1D 0 0 0 1", "the read 1D texture"),
    ] {
        assert!(
            text.lines().any(|line| line.contains("= OpTypeImage ") && line.contains(shape)),
            "no heap image for {what}:\n{text}"
        );
    }

    let mut emitted = reflection
        .bindings
        .iter()
        .filter_map(|resource| resource.texture_shape)
        .map(|shape| {
            (
                shape.dimension,
                shape.arrayed,
                shape.component,
                shape.writable,
            )
        })
        .collect::<Vec<_>>();
    emitted.sort_by_key(|shape| format!("{shape:?}"));
    assert_eq!(
        emitted,
        vec![
            (TextureDimension::D1, false, TextureComponent::Sint, false),
            (TextureDimension::D2, false, TextureComponent::Float, true),
            (TextureDimension::D2, true, TextureComponent::Float, false),
            (TextureDimension::D3, false, TextureComponent::Uint, false),
        ]
    );
}

#[test]
fn a_texel_read_cube_reads_the_cube_view_its_heap_slot_holds() {
    // The plugin writes a texture's own view into its bindless slot: VK_IMAGE_VIEW_TYPE_CUBE for a cube. The image
    // the read goes through must therefore be Dim Cube too (VUID-vkCmdDispatch-viewType-07752); a 2D-array image over
    // that slot is a view-type mismatch, and Mesa ANV gives a sampled cube view a SURFTYPE_CUBE surface whose Depth
    // counts cubes, not faces.
    let (spirv, reflection) = translate(CUBE_TEXEL_COPY, Stage::Kernel, "cube_texel_copy");
    assert_shapes_match_the_module("the cube texel copy", &spirv, &reflection);

    let shapes = reflection
        .bindings
        .iter()
        .filter_map(|resource| Some((resource.descriptor?.binding, resource.texture_shape?)))
        .collect::<HashMap<_, _>>();
    let source = shapes[&32];
    assert_eq!(
        (source.dimension, source.arrayed),
        (TextureDimension::Cube, false),
        "the texel-read cube is bound as the cube view the texture has"
    );
    let destination = shapes[&481];
    assert_eq!(
        (destination.dimension, destination.arrayed),
        (TextureDimension::Cube, false)
    );
    assert!(destination.writable && !source.writable);
    assert_eq!(source.component, TextureComponent::Float);

    let text = metal2vulkan::disassemble(&spirv).expect("disassemble");
    let heap = heap_images(&text);
    assert!(
        heap.len() == 1 && heap[0].starts_with("Cube 0 0 0 1 "),
        "the read reaches the heap as a sampled cube, not {heap:?}:\n{text}"
    );
    assert!(
        !text.contains("OpImageFetch"),
        "SPIR-V forbids OpImageFetch on Dim Cube:\n{text}"
    );
    assert!(
        text.contains("OpImageSampleExplicitLod"),
        "the texel is a centre sample at an explicit level:\n{text}"
    );
}

/// One cube texel read per shape Metal has, each in its own kernel, with the read's mip level a kernel argument so
/// the level is seen to reach the instruction.
fn cube_read_kernel(texture_type: &str, access: &str, read: &str, declare: &str) -> String {
    format!(
        r#"target triple = "spirv-unknown-vulkan1.2"

define void @read_cube(ptr addrspace(1) %src, ptr addrspace(1) %out, <2 x i32> %coord, i32 %level) {{
entry:
  %sampler = tail call ptr addrspace(2) @air.get_read_sampler()
{read}
  store <4 x float> %texel, ptr addrspace(1) %out, align 16
  ret void
}}

declare ptr addrspace(2) @air.get_read_sampler()
{declare}

!air.kernel = !{{!0}}
!0 = !{{ptr @read_cube, !1, !2}}
!1 = !{{}}
!2 = !{{!3, !4, !5, !6}}
!3 = !{{i32 0, !"air.texture", !"air.location_index", i32 0, i32 1, !"{access}", !"air.arg_type_name", !"{texture_type}", !"air.arg_name", !"src"}}
!4 = !{{i32 1, !"air.buffer", !"air.buffer_size", i32 16, !"air.location_index", i32 0, i32 1, !"air.write", !"air.address_space", i32 1, !"air.arg_type_size", i32 16, !"air.arg_type_align_size", i32 16, !"air.arg_type_name", !"float4", !"air.arg_name", !"out"}}
!5 = !{{i32 2, !"air.thread_position_in_grid", !"air.arg_type_name", !"uint2", !"air.arg_name", !"coord"}}
!6 = !{{i32 3, !"air.threadgroup_position_in_grid", !"air.arg_type_name", !"uint", !"air.arg_name", !"level"}}
"#
    )
}

#[test]
fn every_cube_texel_read_declares_the_view_type_its_descriptor_holds() {
    let cases = [
        (
            "texturecube<float, read>",
            "air.read",
            "  %r = tail call { <4 x float>, i8 } @air.read_texture_cube.v4f32(ptr addrspace(1) %src, ptr addrspace(2) %sampler, <2 x i32> %coord, i32 3, i32 %level, i32 1)\n  %texel = extractvalue { <4 x float>, i8 } %r, 0",
            "declare { <4 x float>, i8 } @air.read_texture_cube.v4f32(ptr addrspace(1), ptr addrspace(2), <2 x i32>, i32, i32, i32)",
            (TextureDimension::Cube, false),
            "Cube 0 0 0 1",
        ),
        (
            "texturecube_array<float, read>",
            "air.read",
            "  %r = tail call { <4 x float>, i8 } @air.read_texture_cube_array.v4f32(ptr addrspace(1) %src, ptr addrspace(2) %sampler, <2 x i32> %coord, i32 3, i32 2, i32 %level, i32 1)\n  %texel = extractvalue { <4 x float>, i8 } %r, 0",
            "declare { <4 x float>, i8 } @air.read_texture_cube_array.v4f32(ptr addrspace(1), ptr addrspace(2), <2 x i32>, i32, i32, i32, i32)",
            (TextureDimension::Cube, true),
            "Cube 0 1 0 1",
        ),
        (
            "depthcube<float, read>",
            "air.read",
            "  %d = tail call float @air.read_depth_cube.f32(ptr addrspace(1) %src, ptr addrspace(2) %sampler, <2 x i32> %coord, i32 3, i32 %level, i32 1)\n  %texel = insertelement <4 x float> zeroinitializer, float %d, i32 0",
            "declare float @air.read_depth_cube.f32(ptr addrspace(1), ptr addrspace(2), <2 x i32>, i32, i32, i32)",
            (TextureDimension::Cube, false),
            "Cube",
        ),
    ];
    for (texture_type, access, read, declare, shape, heap_image) in cases {
        let source = cube_read_kernel(texture_type, access, read, declare);
        let (spirv, reflection) = translate(&source, Stage::Kernel, texture_type);
        let text = metal2vulkan::disassemble(&spirv).expect("disassemble");
        let reflected = reflection
            .bindings
            .iter()
            .find(|resource| resource.metal_index == 0 && resource.texture_shape.is_some())
            .and_then(|resource| resource.texture_shape)
            .unwrap_or_else(|| panic!("{texture_type}: the texture reflects a shape"));
        assert_eq!(
            (reflected.dimension, reflected.arrayed),
            shape,
            "{texture_type}: the consumer makes the view this reflects"
        );
        let heap = heap_images(&text);
        assert_eq!(heap.len(), 1, "{texture_type}: one heap image:\n{text}");
        assert!(
            heap[0].starts_with(heap_image),
            "{texture_type}: the heap image {:?} is not the {heap_image} view its slot holds:\n{text}",
            heap[0]
        );
        assert!(
            !text.lines().any(|line| line.contains("= OpTypeImage") && line.contains(" 2D 0 1 ")),
            "{texture_type}: no 2D-array image is declared over a cube view:\n{text}"
        );
        assert!(
            !text.contains("OpImageFetch"),
            "{texture_type}: OpImageFetch may not read Dim Cube:\n{text}"
        );
        // the read's level reaches the sample: a float conversion of the %level argument is its Lod operand
        let sample = text
            .lines()
            .find(|line| line.contains("OpImageSampleExplicitLod"))
            .unwrap_or_else(|| panic!("{texture_type}: the texel is sampled:\n{text}"));
        let lod = sample.split_whitespace().last().expect("the Lod operand");
        assert!(
            text.lines()
                .any(|line| line.trim_start().starts_with(&format!("{lod} = OpConvertUToF"))),
            "{texture_type}: the Lod {lod} is not the converted level argument:\n{text}"
        );
    }
}

#[test]
fn a_read_write_cube_reads_its_storage_cube_view_by_face_layer() {
    // A storage cube's view is the same cube view, which Vulkan lets OpImageRead address as (x, y, face).
    let source = cube_read_kernel(
        "texturecube<float, read_write>",
        "air.read_write",
        "  %r = tail call { <4 x float>, i8 } @air.read_texture_cube.v4f32(ptr addrspace(1) %src, ptr addrspace(2) %sampler, <2 x i32> %coord, i32 3, i32 0, i32 3)\n  %texel = extractvalue { <4 x float>, i8 } %r, 0\n  tail call void @air.write_texture_cube.v4f32(ptr addrspace(1) %src, <2 x i32> %coord, i32 3, <4 x float> %texel, i32 0, i32 3)",
        "declare { <4 x float>, i8 } @air.read_texture_cube.v4f32(ptr addrspace(1), ptr addrspace(2), <2 x i32>, i32, i32, i32)\ndeclare void @air.write_texture_cube.v4f32(ptr addrspace(1), <2 x i32>, i32, <4 x float>, i32, i32)",
    );
    let (spirv, reflection) = translate(&source, Stage::Kernel, "read_write_cube");
    assert_shapes_match_the_module("the read-write cube", &spirv, &reflection);
    let text = metal2vulkan::disassemble(&spirv).expect("disassemble");
    assert!(text.contains("OpImageRead"), "{text}");
    assert!(
        text.lines()
            .any(|line| line.contains("= OpTypeImage") && line.contains(" Cube 0 0 0 2 ")),
        "the storage image keeps Dim Cube:\n{text}"
    );
    assert!(
        !text.lines().any(|line| line.contains("= OpTypeImage") && line.contains(" 2D ")),
        "{text}"
    );
}

/// The sampled images the module declares over the bindless heap (set 2), as their `OpTypeImage` operands after the
/// sampled type ("Cube 0 0 0 1 Unknown").
fn heap_images(text: &str) -> Vec<String> {
    let lines = text.lines().collect::<Vec<_>>();
    let heap_variables = lines
        .iter()
        .filter_map(|line| {
            let tokens = line.split_whitespace().collect::<Vec<_>>();
            match tokens.as_slice() {
                ["OpDecorate", target, "DescriptorSet", "2"] => Some((*target).to_string()),
                _ => None,
            }
        })
        .collect::<Vec<_>>();
    let mut pointees: HashMap<&str, &str> = HashMap::new();
    let mut elements: HashMap<&str, &str> = HashMap::new();
    let mut variables: HashMap<&str, &str> = HashMap::new();
    let mut images: HashMap<&str, String> = HashMap::new();
    for line in &lines {
        let tokens = line.split_whitespace().collect::<Vec<_>>();
        match tokens.as_slice() {
            [result, "=", "OpTypePointer", _, pointee] => {
                pointees.insert(result, pointee);
            }
            [result, "=", "OpTypeArray", element, _]
            | [result, "=", "OpTypeRuntimeArray", element] => {
                elements.insert(result, element);
            }
            [result, "=", "OpVariable", pointer, _] => {
                variables.insert(result, pointer);
            }
            [result, "=", "OpTypeImage", _, rest @ ..] => {
                images.insert(result, rest.join(" "));
            }
            _ => {}
        }
    }
    let mut out = heap_variables
        .iter()
        .filter_map(|variable| {
            let mut ty = *pointees.get(variables.get(variable.as_str())?)?;
            while let Some(element) = elements.get(ty) {
                ty = element;
            }
            images.get(ty).cloned()
        })
        .collect::<Vec<_>>();
    out.sort();
    out
}

#[test]
#[ignore = "sweeps the public fixture corpus, of which validation/fixtures/public holds 5 files; run with \
            --ignored once the corpus is added"]
fn every_public_fixture_reflects_the_images_it_binds() {
    let mut checked = 0;
    let mut shapes = 0;
    for path in public_fixtures() {
        let source = std::fs::read_to_string(&path).expect("read fixture");
        let label = path
            .file_name()
            .map(|name| name.to_string_lossy().into_owned())
            .unwrap_or_default();
        let Some(stage) = stage_of(&source) else {
            continue;
        };
        let Ok((spirv, reflection)) = metal2vulkan::translate_sanitized_native_reflected(
            &source,
            stage,
            &scratch(&label),
            TransformOptions::default(),
        ) else {
            continue;
        };
        shapes += assert_shapes_match_the_module(&label, &spirv, &reflection);
        checked += 1;
    }
    assert!(
        checked >= 20 && shapes >= 1,
        "only {checked} fixtures carrying {shapes} texture shapes were inspected, so this swept \
         almost nothing"
    );
}

fn assert_shapes_match_the_module(
    label: &str,
    spirv: &[u8],
    reflection: &ShaderReflection,
) -> usize {
    let declared = images_the_module_declares(spirv);
    let mut checked = 0;
    for resource in &reflection.bindings {
        let (Some(shape), Some(location)) = (resource.texture_shape, resource.descriptor) else {
            continue;
        };
        let Some(Some(image)) = declared.get(&location.binding) else {
            continue;
        };
        assert_eq!(
            (
                shape.dimension,
                shape.arrayed,
                shape.multisampled,
                shape.component,
                shape.writable
            ),
            (
                image.dimension,
                image.arrayed,
                image.multisampled,
                image.component,
                image.writable
            ),
            "{label} reflects {:?}({}) at binding {} with a shape the module's OpTypeImage \
             contradicts; a view built from it would not match the image variable",
            resource.kind,
            resource.metal_index,
            location.binding
        );
        checked += 1;
    }
    checked
}

fn images_the_module_declares(spirv: &[u8]) -> HashMap<u32, Option<TextureShape>> {
    let text = metal2vulkan::disassemble(spirv).expect("disassemble the translated module");
    let mut floats = Vec::new();
    let mut signed_integers = Vec::new();
    let mut unsigned_integers = Vec::new();
    let mut images: HashMap<String, TextureShape> = HashMap::new();
    let mut pointees: HashMap<String, String> = HashMap::new();
    let mut elements: HashMap<String, String> = HashMap::new();
    let mut variables: HashMap<String, String> = HashMap::new();
    let mut bindings: Vec<(String, u32)> = Vec::new();
    for line in text.lines() {
        let tokens = line.split_whitespace().collect::<Vec<_>>();
        match tokens.as_slice() {
            ["OpDecorate", target, "Binding", value] => {
                if let Ok(value) = value.parse::<u32>() {
                    bindings.push(((*target).to_string(), value));
                }
            }
            [result, "=", "OpTypeFloat", ..] => floats.push((*result).to_string()),
            [result, "=", "OpTypeInt", _, signedness] => {
                if *signedness == "1" {
                    signed_integers.push((*result).to_string());
                } else {
                    unsigned_integers.push((*result).to_string());
                }
            }
            [result, "=", "OpTypePointer", _, pointee] => {
                pointees.insert((*result).to_string(), (*pointee).to_string());
            }
            [result, "=", "OpTypeArray", element, _]
            | [result, "=", "OpTypeRuntimeArray", element] => {
                elements.insert((*result).to_string(), (*element).to_string());
            }
            [result, "=", "OpVariable", pointer, _] => {
                variables.insert((*result).to_string(), (*pointer).to_string());
            }
            [result, "=", "OpTypeImage", sampled, dimension, _, arrayed, multisampled, sampled_operand, format] =>
            {
                let component = if floats.iter().any(|id| id == sampled) {
                    TextureComponent::Float
                } else if signed_integers.iter().any(|id| id == sampled) {
                    TextureComponent::Sint
                } else if unsigned_integers.iter().any(|id| id == sampled) {
                    TextureComponent::Uint
                } else {
                    continue;
                };
                let dimension = match *dimension {
                    "1D" => TextureDimension::D1,
                    "2D" => TextureDimension::D2,
                    "3D" => TextureDimension::D3,
                    "Cube" => TextureDimension::Cube,
                    "Buffer" => TextureDimension::Buffer,
                    _ => continue,
                };
                images.insert(
                    (*result).to_string(),
                    TextureShape {
                        dimension,
                        arrayed: *arrayed != "0",
                        multisampled: *multisampled != "0",
                        component,
                        writable: *sampled_operand == "2",
                        array_ref: false,
                        array_length: None,
                        storage_format: metal2vulkan::meta::TextureFormat::ALL.into_iter().find(
                            |candidate| format!("{:?}", candidate.to_spirv_format()) == *format,
                        ),
                    },
                );
            }
            _ => {}
        }
    }
    let mut declared: HashMap<u32, Option<TextureShape>> = HashMap::new();
    for (variable, binding) in bindings {
        let Some(pointer) = variables.get(&variable) else {
            continue;
        };
        let Some(mut pointee) = pointees.get(pointer).cloned() else {
            continue;
        };
        while let Some(element) = elements.get(&pointee) {
            pointee = element.clone();
        }
        let Some(image) = images.get(&pointee).copied() else {
            continue;
        };
        declared
            .entry(binding)
            .and_modify(|seen| {
                if *seen != Some(image) {
                    *seen = None;
                }
            })
            .or_insert(Some(image));
    }
    declared
}

fn translate(source: &str, stage: Stage, label: &str) -> (Vec<u8>, ShaderReflection) {
    metal2vulkan::translate_sanitized_native_reflected(
        source,
        stage,
        &scratch(label),
        TransformOptions::default(),
    )
    .unwrap_or_else(|error| panic!("{label} translates: {error}"))
}

fn scratch(label: &str) -> PathBuf {
    let directory = std::env::temp_dir().join(format!(
        "m2v_reflected_images_{}_{}",
        std::process::id(),
        label.replace(['/', '.'], "_")
    ));
    std::fs::create_dir_all(&directory).expect("scratch directory");
    directory
}

fn stage_of(source: &str) -> Option<Stage> {
    if source.contains("!air.vertex =") {
        Some(Stage::Vertex)
    } else if source.contains("!air.fragment =") {
        Some(Stage::Fragment)
    } else if source.contains("!air.kernel =") {
        Some(Stage::Kernel)
    } else {
        None
    }
}

fn public_fixtures() -> Vec<PathBuf> {
    let root = Path::new(env!("CARGO_MANIFEST_DIR")).join("validation/fixtures/public");
    let mut paths = std::fs::read_dir(&root)
        .unwrap_or_else(|error| panic!("read {}: {error}", root.display()))
        .filter_map(Result::ok)
        .map(|entry| entry.path())
        .filter(|path| path.extension().is_some_and(|extension| extension == "ll"))
        .collect::<Vec<_>>();
    paths.sort();
    paths
}
