target triple = "air64_v28-apple-macosx26.7.0"

%ArgsTextures = type { %"struct.metal::texture2d", %"struct.metal::texture2d", %"struct.metal::texture2d" }
%"struct.metal::texture2d" = type { ptr addrspace(1) }

define <{ <4 x float> }> @fs(<4 x float> noundef %position, ptr addrspace(2) noundef readonly align 8 %textures) local_unnamed_addr #0 {
entry:
  %albedo.field = getelementptr inbounds %ArgsTextures, ptr addrspace(2) %textures, i64 0, i32 1
  %albedo.id = load i64, ptr addrspace(2) %albedo.field, align 8
  %albedo = inttoptr i64 %albedo.id to ptr addrspace(1)
  %depth.field = getelementptr inbounds %ArgsTextures, ptr addrspace(2) %textures, i64 0, i32 2
  %depth.id = load i64, ptr addrspace(2) %depth.field, align 8
  %depth = inttoptr i64 %depth.id to ptr addrspace(1)
  %xy = shufflevector <4 x float> %position, <4 x float> poison, <2 x i32> <i32 0, i32 1>
  %coord = tail call <2 x i32> @air.convert.s.v2i32.f.v2f32(<2 x float> %xy)
  %sampler = tail call ptr addrspace(2) @air.get_read_sampler()
  %texel = tail call { <4 x float>, i8 } @air.read_texture_2d.v4f32(ptr addrspace(1) %depth, ptr addrspace(2) %sampler, <2 x i32> %coord, <2 x i32> zeroinitializer, i32 0, i32 0)
  %value = extractvalue { <4 x float>, i8 } %texel, 0
  %d = extractelement <4 x float> %value, i64 0
  %near = fcmp ult float %d, 1.000000e+00
  br i1 %near, label %if.end, label %if.then

if.then:
  tail call void @air.discard_fragment()
  br label %if.end

if.end:
  %width = tail call i32 @air.get_width_texture_2d(ptr addrspace(1) %depth, i32 0)
  %other = tail call { <4 x float>, i8 } @air.read_texture_2d.v4f32(ptr addrspace(1) %albedo, ptr addrspace(2) %sampler, <2 x i32> %coord, <2 x i32> zeroinitializer, i32 0, i32 0)
  %other.value = extractvalue { <4 x float>, i8 } %other, 0
  %widthf = uitofp i32 %width to float
  %scaled = insertelement <4 x float> %other.value, float %widthf, i64 0
  %color = fadd <4 x float> %scaled, %value
  %out = insertvalue <{ <4 x float> }> undef, <4 x float> %color, 0
  ret <{ <4 x float> }> %out
}

declare { <4 x float>, i8 } @air.read_texture_2d.v4f32(ptr addrspace(1) readonly captures(none), ptr addrspace(2), <2 x i32>, <2 x i32>, i32, i32) local_unnamed_addr #1
declare ptr addrspace(2) @air.get_read_sampler() local_unnamed_addr #2
declare i32 @air.get_width_texture_2d(ptr addrspace(1) readonly captures(none), i32) local_unnamed_addr #1
declare void @air.discard_fragment() local_unnamed_addr #3
declare <2 x i32> @air.convert.s.v2i32.f.v2f32(<2 x float>) local_unnamed_addr #2

attributes #0 = { convergent nounwind }
attributes #1 = { mustprogress nofree nounwind willreturn memory(argmem: read) }
attributes #2 = { mustprogress nofree nosync nounwind willreturn memory(none) }
attributes #3 = { mustprogress nounwind willreturn }

!air.version = !{!0}
!air.language_version = !{!1}
!air.fragment = !{!2}

!0 = !{i32 2, i32 8, i32 0}
!1 = !{!"Metal", i32 4, i32 0, i32 0}
!2 = !{ptr @fs, !3, !5}
!3 = !{!4}
!4 = !{!"air.render_target", i32 0, i32 0, !"air.arg_type_name", !"float4", !"air.arg_name", !"color"}
!5 = !{!6, !7}
!6 = !{i32 0, !"air.position", !"air.center", !"air.no_perspective", !"air.arg_type_name", !"float4", !"air.arg_name", !"position"}
!7 = !{i32 1, !"air.indirect_buffer", !"air.buffer_size", i32 24, !"air.location_index", i32 0, i32 1, !"air.read", !"air.address_space", i32 2, !"air.struct_type_info", !8, !"air.arg_type_size", i32 24, !"air.arg_type_align_size", i32 8, !"air.arg_type_name", !"ArgsTextures", !"air.arg_name", !"textures"}
!8 = !{i32 0, i32 8, i32 0, !"texture2d<float, sample>", !"normal", !"air.indirect_argument", !9, i32 8, i32 8, i32 0, !"texture2d<float, sample>", !"albedo", !"air.indirect_argument", !10, i32 16, i32 8, i32 0, !"texture2d<float, sample>", !"depth", !"air.indirect_argument", !11}
!9 = !{i32 0, !"air.texture", !"air.location_index", i32 0, i32 1, !"air.sample", !"air.arg_type_name", !"texture2d<float, sample>", !"air.arg_name", !"normal"}
!10 = !{i32 1, !"air.texture", !"air.location_index", i32 1, i32 1, !"air.sample", !"air.arg_type_name", !"texture2d<float, sample>", !"air.arg_name", !"albedo"}
!11 = !{i32 2, !"air.texture", !"air.location_index", i32 2, i32 1, !"air.sample", !"air.arg_type_name", !"texture2d<float, sample>", !"air.arg_name", !"depth"}
