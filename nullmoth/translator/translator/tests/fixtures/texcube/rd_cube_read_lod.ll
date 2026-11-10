; ModuleID = 'nvmtl-air'
source_filename = "rd_cube"
target datalayout = "e-p:64:64:64-i1:8:8-i8:8:8-i16:16:16-i32:32:32-i64:64:64-f32:32:32-f64:64:64-v16:16:16-v24:32:32-v32:32:32-v48:64:64-v64:64:64-v96:128:128-v128:128:128-v192:256:256-v256:256:256-v512:512:512-v1024:1024:1024-n8:16:32"
target triple = "air64_v29-apple-macosx27.0.0"

%struct.P = type { i32, i32, i32, i32 }

; Function Attrs: mustprogress nofree nounwind willreturn
define void @rd_cube(ptr addrspace(1) %t.coerce, ptr addrspace(1) noundef writeonly captures(none) "air-buffer-no-alias" %o, ptr addrspace(2) noundef readonly align 4 captures(none) dereferenceable(16) "air-buffer-no-alias" %p, <3 x i32> noundef %g) local_unnamed_addr #0 {
entry:
  %0 = extractelement <3 x i32> %g, i64 0
  %w = getelementptr inbounds %struct.P, ptr addrspace(2) %p, i64 0, i32 0
  %1 = load i32, ptr addrspace(2) %w, align 4, !tbaa !22, !alias.scope !27, !noalias !30
  %cmp.not = icmp ult i32 %0, %1
  br i1 %cmp.not, label %lor.lhs.false, label %return

lor.lhs.false:                                    ; preds = %entry
  %2 = extractelement <3 x i32> %g, i64 1
  %h = getelementptr inbounds %struct.P, ptr addrspace(2) %p, i64 0, i32 1
  %3 = load i32, ptr addrspace(2) %h, align 4, !tbaa !33, !alias.scope !27, !noalias !30
  %cmp1.not = icmp ult i32 %2, %3
  br i1 %cmp1.not, label %if.end, label %return

if.end:                                           ; preds = %lor.lhs.false
  %4 = shufflevector <3 x i32> %g, <3 x i32> poison, <2 x i32> <i32 0, i32 1>
  %5 = extractelement <3 x i32> %g, i64 2
  %lod = getelementptr inbounds %struct.P, ptr addrspace(2) %p, i64 0, i32 2
  %6 = load i32, ptr addrspace(2) %lod, align 4, !tbaa !34, !alias.scope !27, !noalias !30
  %7 = tail call ptr addrspace(2) @air.get_read_sampler() #3
  %8 = tail call { <4 x float>, i8 } @air.read_texture_cube.v4f32(ptr addrspace(1) readonly captures(none) %t.coerce, ptr addrspace(2) %7, <2 x i32> %4, i32 %5, i32 %6, i32 1) #4
  %9 = extractvalue { <4 x float>, i8 } %8, 0
  %mul = mul i32 %3, %5
  %add = add i32 %mul, %2
  %mul4 = mul i32 %add, %1
  %add5 = add i32 %mul4, %0
  %idxprom = zext i32 %add5 to i64
  %arrayidx = getelementptr inbounds <4 x float>, ptr addrspace(1) %o, i64 %idxprom
  store <4 x float> %9, ptr addrspace(1) %arrayidx, align 16, !tbaa !35, !alias.scope !37, !noalias !38
  br label %return

return:                                           ; preds = %if.end, %lor.lhs.false, %entry
  ret void
}

; Function Attrs: mustprogress nofree nounwind willreturn memory(argmem: read)
declare { <4 x float>, i8 } @air.read_texture_cube.v4f32(ptr addrspace(1) readonly captures(none), ptr addrspace(2), <2 x i32>, i32, i32, i32) local_unnamed_addr #1

; Function Attrs: mustprogress nofree nounwind willreturn memory(inaccessiblemem: read)
declare ptr addrspace(2) @air.get_read_sampler() local_unnamed_addr #2

attributes #0 = { mustprogress nofree nounwind willreturn "approx-func-fp-math"="true" "frame-pointer"="all" "min-legal-vector-width"="128" "no-builtins" "no-infs-fp-math"="true" "no-nans-fp-math"="true" "no-signed-zeros-fp-math"="true" "no-trapping-math"="true" "stack-protector-buffer-size"="8" "unsafe-fp-math"="true" }
attributes #1 = { mustprogress nofree nounwind willreturn memory(argmem: read) }
attributes #2 = { mustprogress nofree nounwind willreturn memory(inaccessiblemem: read) }
attributes #3 = { nounwind willreturn memory(inaccessiblemem: read) }
attributes #4 = { nounwind willreturn memory(argmem: read) }

!llvm.module.flags = !{!0, !1, !2, !3, !4, !5, !6, !7}
!llvm.ident = !{!8}
!air.version = !{!9}
!air.language_version = !{!10}
!air.compile_options = !{!11, !12, !13}
!air.kernel = !{!14}

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
!10 = !{!"Metal", i32 4, i32 1, i32 0}
!11 = !{!"air.compile.denorms_disable"}
!12 = !{!"air.compile.fast_math_enable"}
!13 = !{!"air.compile.framebuffer_fetch_enable"}
!14 = !{ptr @rd_cube, !15, !16}
!15 = !{}
!16 = !{!17, !18, !19, !21}
!17 = !{i32 0, !"air.texture", !"air.location_index", i32 0, i32 1, !"air.read", !"air.arg_type_name", !"texturecube<float, read>", !"air.arg_name", !"t"}
!18 = !{i32 1, !"air.buffer", !"air.location_index", i32 0, i32 1, !"air.read_write", !"air.address_space", i32 1, !"air.arg_type_size", i32 16, !"air.arg_type_align_size", i32 16, !"air.arg_type_name", !"float4", !"air.arg_name", !"o"}
!19 = !{i32 2, !"air.buffer", !"air.buffer_size", i32 16, !"air.location_index", i32 1, i32 1, !"air.read", !"air.address_space", i32 2, !"air.struct_type_info", !20, !"air.arg_type_size", i32 16, !"air.arg_type_align_size", i32 4, !"air.arg_type_name", !"P", !"air.arg_name", !"p"}
!20 = !{i32 0, i32 4, i32 0, !"uint", !"w", i32 4, i32 4, i32 0, !"uint", !"h", i32 8, i32 4, i32 0, !"uint", !"lod", i32 12, i32 4, i32 0, !"uint", !"pad"}
!21 = !{i32 3, !"air.thread_position_in_grid", !"air.arg_type_name", !"uint3", !"air.arg_name", !"g"}
!22 = !{!23, !24, i64 0}
!23 = !{!"_ZTS1P", !24, i64 0, !24, i64 4, !24, i64 8, !24, i64 12}
!24 = !{!"int", !25, i64 0}
!25 = !{!"omnipotent char", !26, i64 0}
!26 = !{!"Simple C++ TBAA"}
!27 = !{!28}
!28 = distinct !{!28, !29, !"air-alias-scope-arg(2)"}
!29 = distinct !{!29, !"air-alias-scopes(rd_cube)"}
!30 = !{!31, !32}
!31 = distinct !{!31, !29, !"air-alias-scope-textures"}
!32 = distinct !{!32, !29, !"air-alias-scope-arg(1)"}
!33 = !{!23, !24, i64 4}
!34 = !{!23, !24, i64 8}
!35 = !{!36, !36, i64 0}
!36 = !{!"float", !25, i64 0}
!37 = !{!32}
!38 = !{!31, !28}
