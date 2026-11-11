; Two samplers of one WebKit-style argument buffer (their addresses, as WebKit passes a sampler) merged by a select (the fragment's x chooses), then sampled: the
; merged sampler must read the chosen sampler-heap slot (an OpSelect of the two slots), not fall back or be refused.
target datalayout = "e-p:64:64:64-i1:8:8-i8:8:8-i16:16:16-i32:32:32-i64:64:64-f32:32:32-f64:64:64-v16:16:16-v24:32:32-v32:32:32-v48:64:64-v64:64:64-v96:128:128-v128:128:128-v192:256:256-v256:256:256-v512:512:512-v1024:1024:1024-n8:16:32"
target triple = "air64_v28-apple-macosx26.7.0"

%ArgumentBuffer = type { %"struct.metal::sampler", %"struct.metal::texture2d", ptr addrspace(2), %"struct.metal::sampler" }
%"struct.metal::sampler" = type { ptr addrspace(2) }
%"struct.metal::texture2d" = type { ptr addrspace(1) }

define <{ <4 x float> }> @fs(<4 x float> noundef %position, ptr addrspace(2) noundef readonly align 8 dereferenceable(32) "air-buffer-no-alias" %group) local_unnamed_addr #0 {
entry:
  %texture.field = getelementptr inbounds %ArgumentBuffer, ptr addrspace(2) %group, i64 0, i32 1
  %texture.id = load i64, ptr addrspace(2) %texture.field, align 8
  %texture = inttoptr i64 %texture.id to ptr addrspace(1)
  %s0.field = getelementptr inbounds %ArgumentBuffer, ptr addrspace(2) %group, i64 0, i32 0, i32 0
  %s1.field = getelementptr inbounds %ArgumentBuffer, ptr addrspace(2) %group, i64 0, i32 3, i32 0
  %xy = shufflevector <4 x float> %position, <4 x float> poison, <2 x i32> <i32 0, i32 1>
  %x = extractelement <4 x float> %position, i64 0
  %left = fcmp olt float %x, 5.120000e+02
  %sampler = select i1 %left, ptr addrspace(2) %s0.field, ptr addrspace(2) %s1.field
  %sample = tail call { <4 x float>, i8 } @air.sample_texture_2d.v4f32(ptr addrspace(1) %texture, ptr addrspace(2) %sampler, <2 x float> %xy, i1 true, <2 x i32> zeroinitializer, i1 false, float 0.000000e+00, float 0.000000e+00, i32 0)
  %color = extractvalue { <4 x float>, i8 } %sample, 0
  %out = insertvalue <{ <4 x float> }> undef, <4 x float> %color, 0
  ret <{ <4 x float> }> %out
}

declare { <4 x float>, i8 } @air.sample_texture_2d.v4f32(ptr addrspace(1), ptr addrspace(2), <2 x float>, i1, <2 x i32>, i1, float, float, i32) local_unnamed_addr #1

attributes #0 = { convergent mustprogress nofree nounwind willreturn memory(read) }
attributes #1 = { convergent mustprogress nofree nounwind willreturn memory(argmem: read) }

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
!7 = !{i32 1, !"air.indirect_buffer", !"air.buffer_size", i32 32, !"air.location_index", i32 0, i32 1, !"air.read", !"air.address_space", i32 2, !"air.struct_type_info", !8, !"air.arg_type_size", i32 32, !"air.arg_type_align_size", i32 8, !"air.arg_type_name", !"ArgumentBuffer", !"air.arg_name", !"group"}
!8 = !{i32 0, i32 8, i32 0, !"sampler", !"smp", !"air.indirect_argument", !9, i32 8, i32 8, i32 0, !"texture2d<float, sample>", !"tex", !"air.indirect_argument", !10, i32 16, i32 8, i32 0, !"float2", !"u", !"air.indirect_argument", !11, i32 24, i32 8, i32 0, !"sampler", !"smp2", !"air.indirect_argument", !12}
!9 = !{i32 0, !"air.sampler", !"air.location_index", i32 0, i32 1, !"air.arg_type_name", !"sampler", !"air.arg_name", !"smp"}
!10 = !{i32 1, !"air.texture", !"air.location_index", i32 1, i32 1, !"air.sample", !"air.arg_type_name", !"texture2d<float, sample>", !"air.arg_name", !"tex"}
!11 = !{i32 2, !"air.buffer", !"air.buffer_size", i32 8, !"air.location_index", i32 2, i32 1, !"air.read", !"air.address_space", i32 2, !"air.arg_type_size", i32 8, !"air.arg_type_align_size", i32 8, !"air.arg_type_name", !"float2", !"air.arg_name", !"u"}
!12 = !{i32 3, !"air.sampler", !"air.location_index", i32 3, i32 1, !"air.arg_type_name", !"sampler", !"air.arg_name", !"smp2"}
