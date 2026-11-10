; ModuleID = 'nvmtl-air'
source_filename = "pull_offset"
target datalayout = "e-p:64:64:64-i1:8:8-i8:8:8-i16:16:16-i32:32:32-i64:64:64-f32:32:32-f64:64:64-v16:16:16-v24:32:32-v32:32:32-v48:64:64-v64:64:64-v96:128:128-v128:128:128-v192:256:256-v256:256:256-v512:512:512-v1024:1024:1024-n8:16:32"
target triple = "air64_v29-apple-macosx27.0.0"

; Function Attrs: mustprogress nofree nounwind willreturn memory(read)
define <4 x float> @pull_offset(<4 x float> %i.0, ptr addrspace(1) %i.1, ptr addrspace(1) %i.2, ptr addrspace(1) %i.3, ptr addrspace(1) %i.4, ptr addrspace(2) noundef readonly align 8 captures(none) dereferenceable(8) "air-buffer-no-alias" %o) local_unnamed_addr #0 {
entry:
  %0 = load <2 x float>, ptr addrspace(2) %o, align 8, !tbaa !24, !alias.scope !27, !noalias !30
  %1 = tail call fast <4 x float> @air.interpolate_offset_perspective.v4f32(ptr addrspace(1) readonly captures(none) %i.1, <2 x float> %0) #2, !alias.scope !35, !noalias !36
  %2 = tail call fast <2 x float> @air.interpolate_offset_no_perspective.v2f32(ptr addrspace(1) readonly captures(none) %i.2, <2 x float> %0) #2, !alias.scope !37, !noalias !38
  %vecinit = shufflevector <2 x float> %2, <2 x float> poison, <4 x i32> <i32 0, i32 1, i32 poison, i32 poison>
  %3 = tail call fast float @air.interpolate_offset_perspective.f32(ptr addrspace(1) readonly captures(none) %i.3, <2 x float> %0) #2, !alias.scope !39, !noalias !40
  %vecinit9 = insertelement <4 x float> %vecinit, float %3, i64 2
  %4 = tail call fast <3 x half> @air.interpolate_offset_no_perspective.v3f16(ptr addrspace(1) readonly captures(none) %i.4, <2 x float> %0) #2, !alias.scope !41, !noalias !42
  %5 = extractelement <3 x half> %4, i64 0
  %conv = fpext half %5 to float
  %vecinit12 = insertelement <4 x float> %vecinit9, float %conv, i64 3
  %add = fadd fast <4 x float> %vecinit12, %1
  ret <4 x float> %add
}

; Function Attrs: mustprogress nofree nounwind willreturn memory(argmem: read)
declare <3 x half> @air.interpolate_offset_no_perspective.v3f16(ptr addrspace(1) readonly captures(none), <2 x float>) local_unnamed_addr #1

; Function Attrs: mustprogress nofree nounwind willreturn memory(argmem: read)
declare float @air.interpolate_offset_perspective.f32(ptr addrspace(1) readonly captures(none), <2 x float>) local_unnamed_addr #1

; Function Attrs: mustprogress nofree nounwind willreturn memory(argmem: read)
declare <2 x float> @air.interpolate_offset_no_perspective.v2f32(ptr addrspace(1) readonly captures(none), <2 x float>) local_unnamed_addr #1

; Function Attrs: mustprogress nofree nounwind willreturn memory(argmem: read)
declare <4 x float> @air.interpolate_offset_perspective.v4f32(ptr addrspace(1) readonly captures(none), <2 x float>) local_unnamed_addr #1

attributes #0 = { mustprogress nofree nounwind willreturn memory(read) "approx-func-fp-math"="true" "frame-pointer"="all" "min-legal-vector-width"="128" "no-builtins" "no-infs-fp-math"="true" "no-nans-fp-math"="true" "no-signed-zeros-fp-math"="true" "no-trapping-math"="true" "stack-protector-buffer-size"="8" "unsafe-fp-math"="true" }
attributes #1 = { mustprogress nofree nounwind willreturn memory(argmem: read) }
attributes #2 = { nounwind willreturn memory(argmem: read) }

!llvm.module.flags = !{!0, !1, !2, !3, !4, !5, !6, !7}
!llvm.ident = !{!8}
!air.version = !{!9}
!air.language_version = !{!10}
!air.compile_options = !{!11, !12, !13}
!air.fragment = !{!14}

!0 = !{i32 1, !"wchar_size", i32 4}
!1 = !{i32 7, !"frame-pointer", i32 2}
!2 = !{i32 7, !"air.max_device_buffers", i32 31}
!3 = !{i32 7, !"air.max_constant_buffers", i32 31}
!4 = !{i32 7, !"air.max_threadgroup_buffers", i32 31}
!5 = !{i32 7, !"air.max_textures", i32 128}
!6 = !{i32 7, !"air.max_read_write_textures", i32 8}
!7 = !{i32 7, !"air.max_samplers", i32 16}
!8 = !{!"Apple metal version 32023.921 (metalfe-32023.921.5)"}
!9 = !{i32 2, i32 9, i32 0}
!10 = !{!"Metal", i32 4, i32 0, i32 0}
!11 = !{!"air.compile.denorms_disable"}
!12 = !{!"air.compile.fast_math_enable"}
!13 = !{!"air.compile.framebuffer_fetch_enable"}
!14 = !{ptr @pull_offset, !15, !17}
!15 = !{!16}
!16 = !{!"air.render_target", i32 0, i32 0, !"air.arg_type_name", !"float4"}
!17 = !{!18, !19, !20, !21, !22, !23}
!18 = !{i32 0, !"air.position", !"air.center", !"air.no_perspective", !"air.arg_type_name", !"float4", !"air.arg_name", !"pos", !"air.arg_unused"}
!19 = !{i32 1, !"air.fragment_input", !"user(a)", !"air.interpolation_function", !"air.perspective", !"air.arg_type_name", !"float4", !"air.arg_name", !"p4"}
!20 = !{i32 2, !"air.fragment_input", !"user(b)", !"air.interpolation_function", !"air.no_perspective", !"air.arg_type_name", !"float2", !"air.arg_name", !"n2"}
!21 = !{i32 3, !"air.fragment_input", !"user(c)", !"air.interpolation_function", !"air.perspective", !"air.arg_type_name", !"float", !"air.arg_name", !"p1"}
!22 = !{i32 4, !"air.fragment_input", !"user(d)", !"air.interpolation_function", !"air.no_perspective", !"air.arg_type_name", !"half3", !"air.arg_name", !"h3"}
!23 = !{i32 5, !"air.buffer", !"air.buffer_size", i32 8, !"air.location_index", i32 0, i32 1, !"air.read", !"air.address_space", i32 2, !"air.arg_type_size", i32 8, !"air.arg_type_align_size", i32 8, !"air.arg_type_name", !"float2", !"air.arg_name", !"o"}
!24 = !{!25, !25, i64 0}
!25 = !{!"omnipotent char", !26, i64 0}
!26 = !{!"Simple C++ TBAA"}
!27 = !{!28}
!28 = distinct !{!28, !29, !"air-alias-scope-arg(5)"}
!29 = distinct !{!29, !"air-alias-scopes(pull_offset)"}
!30 = !{!31, !32, !33, !34}
!31 = distinct !{!31, !29, !"air-alias-scope-arg(1)"}
!32 = distinct !{!32, !29, !"air-alias-scope-arg(2)"}
!33 = distinct !{!33, !29, !"air-alias-scope-arg(3)"}
!34 = distinct !{!34, !29, !"air-alias-scope-arg(4)"}
!35 = !{!31}
!36 = !{!32, !33, !34, !28}
!37 = !{!32}
!38 = !{!31, !33, !34, !28}
!39 = !{!33}
!40 = !{!31, !32, !34, !28}
!41 = !{!34}
!42 = !{!31, !32, !33, !28}
