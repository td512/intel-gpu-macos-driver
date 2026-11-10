; ModuleID = 'nvmtl-air'
; vsUshortICB: AIR as the Metal plugin hands it to the translator (tbaa and alias-scope metadata removed)
source_filename = "vsUshortICB"
target datalayout = "e-p:64:64:64-i1:8:8-i8:8:8-i16:16:16-i32:32:32-i64:64:64-f32:32:32-f64:64:64-v16:16:16-v24:32:32-v32:32:32-v48:64:64-v64:64:64-v96:128:128-v128:128:128-v192:256:256-v256:256:256-v512:512:512-v1024:1024:1024-n8:16:32"
target triple = "air64_v28-apple-macosx26.7.0"

%struct.IndexDataUshort = type <{ i64, i32, i32, ptr addrspace(1), i32, i32, i32, i32, i32, i32, i32, [4 x i8] }>
%struct.ICBContainer = type { ptr addrspace(1), %"struct.metal::command_buffer" }
%"struct.metal::command_buffer" = type { ptr addrspace(1) }

; Function Attrs: mustprogress nounwind willreturn
define void @vsUshortICB(ptr addrspace(1) noundef readonly captures(none) "air-buffer-no-alias" %indexData, ptr addrspace(1) noundef readonly captures(none) "air-buffer-no-alias" %icb_container, i32 noundef %indexId) local_unnamed_addr #0 {
entry:
  %primitiveType = getelementptr inbounds %struct.IndexDataUshort, ptr addrspace(1) %indexData, i64 0, i32 10
  %0 = load i32, ptr addrspace(1) %primitiveType, align 8
  %cmp = icmp eq i32 %0, 4
  %cmp2 = icmp eq i32 %0, 2
  %narrow = or i1 %cmp, %cmp2
  %1 = zext i1 %narrow to i32
  %indexBuffer = getelementptr inbounds %struct.IndexDataUshort, ptr addrspace(1) %indexData, i64 0, i32 3
  %2 = load ptr addrspace(1), ptr addrspace(1) %indexBuffer, align 8
  %indexBufferElementCountMinusOne = getelementptr inbounds %struct.IndexDataUshort, ptr addrspace(1) %indexData, i64 0, i32 4
  %3 = load i32, ptr addrspace(1) %indexBufferElementCountMinusOne, align 8
  %firstIndex = getelementptr inbounds %struct.IndexDataUshort, ptr addrspace(1) %indexData, i64 0, i32 7
  %4 = load i32, ptr addrspace(1) %firstIndex, align 4
  %add = add i32 %4, %indexId
  %5 = tail call i32 @air.min.u.i32(i32 %3, i32 %add) #3
  %idxprom = zext i32 %5 to i64
  %arrayidx = getelementptr inbounds i16, ptr addrspace(1) %2, i64 %idxprom
  %6 = load i16, ptr addrspace(1) %arrayidx, align 2
  %conv = zext i16 %6 to i32
  %add3 = add nuw nsw i32 %conv, %1
  %baseVertex = getelementptr inbounds %struct.IndexDataUshort, ptr addrspace(1) %indexData, i64 0, i32 8
  %7 = load i32, ptr addrspace(1) %baseVertex, align 8
  %8 = tail call i32 @air.add_sat.u.i32(i32 %add3, i32 %7) #3
  %minVertexCount = getelementptr inbounds %struct.IndexDataUshort, ptr addrspace(1) %indexData, i64 0, i32 1
  %9 = load i32, ptr addrspace(1) %minVertexCount, align 8
  %add5 = add i32 %9, %1
  %cmp6.not = icmp ult i32 %8, %add5
  br i1 %cmp6.not, label %if.end, label %if.then

if.then:                                          ; preds = %entry
  %outOfBoundsRead = getelementptr inbounds %struct.ICBContainer, ptr addrspace(1) %icb_container, i64 0, i32 0
  %10 = load ptr addrspace(1), ptr addrspace(1) %outOfBoundsRead, align 8
  store i32 1, ptr addrspace(1) %10, align 4
  %agg.tmp.sroa.0.0..sroa_idx = getelementptr inbounds %struct.ICBContainer, ptr addrspace(1) %icb_container, i64 0, i32 1, i32 0
  %agg.tmp.sroa.0.0.copyload = load ptr addrspace(1), ptr addrspace(1) %agg.tmp.sroa.0.0..sroa_idx, align 8
  %renderCommand = getelementptr inbounds %struct.IndexDataUshort, ptr addrspace(1) %indexData, i64 0, i32 0
  %11 = load i64, ptr addrspace(1) %renderCommand, align 8
  %conv7 = trunc i64 %11 to i32
  %instanceCount = getelementptr inbounds %struct.IndexDataUshort, ptr addrspace(1) %indexData, i64 0, i32 6
  %12 = load i32, ptr addrspace(1) %instanceCount, align 8
  %13 = load i32, ptr addrspace(1) %baseVertex, align 8
  %baseInstance = getelementptr inbounds %struct.IndexDataUshort, ptr addrspace(1) %indexData, i64 0, i32 9
  %14 = load i32, ptr addrspace(1) %baseInstance, align 4
  tail call void @air.draw_indexed_primitives_render_command.p1i16(ptr addrspace(1) captures(none) %agg.tmp.sroa.0.0.copyload, i32 %conv7, i32 %0, i32 0, ptr addrspace(1) %2, i32 %12, i32 %13, i32 %14) #4
  br label %if.end

if.end:                                           ; preds = %if.then, %entry
  ret void
}

; Function Attrs: mustprogress nounwind willreturn
declare void @air.draw_indexed_primitives_render_command.p1i16(ptr addrspace(1) captures(none), i32, i32, i32, ptr addrspace(1), i32, i32, i32) local_unnamed_addr #1

; Function Attrs: mustprogress nofree nosync nounwind willreturn memory(none)
declare i32 @air.add_sat.u.i32(i32, i32) local_unnamed_addr #2

; Function Attrs: mustprogress nofree nosync nounwind willreturn memory(none)
declare i32 @air.min.u.i32(i32, i32) local_unnamed_addr #2

attributes #0 = { mustprogress nounwind willreturn "approx-func-fp-math"="true" "frame-pointer"="all" "min-legal-vector-width"="0" "no-builtins" "no-infs-fp-math"="true" "no-nans-fp-math"="true" "no-signed-zeros-fp-math"="true" "no-trapping-math"="true" "stack-protector-buffer-size"="8" "unsafe-fp-math"="true" }
attributes #1 = { mustprogress nounwind willreturn }
attributes #2 = { mustprogress nofree nosync nounwind willreturn memory(none) }
attributes #3 = { nounwind willreturn memory(none) }
attributes #4 = { nounwind willreturn }

!llvm.module.flags = !{!0, !1, !2, !3, !4, !5, !6, !7}
!llvm.ident = !{!8}
!air.version = !{!9}
!air.language_version = !{!10}
!air.compile_options = !{!11, !12, !13}
!air.vertex = !{!14}

!0 = !{i32 1, !"wchar_size", i32 4}
!1 = !{i32 7, !"frame-pointer", i32 2}
!2 = !{i32 7, !"air.max_device_buffers", i32 31}
!3 = !{i32 7, !"air.max_constant_buffers", i32 31}
!4 = !{i32 7, !"air.max_threadgroup_buffers", i32 31}
!5 = !{i32 7, !"air.max_textures", i32 128}
!6 = !{i32 7, !"air.max_read_write_textures", i32 8}
!7 = !{i32 7, !"air.max_samplers", i32 16}
!8 = !{!"Apple metal version 32023.886 (metalfe-32023.886.1)"}
!9 = !{i32 2, i32 8, i32 0}
!10 = !{!"Metal", i32 4, i32 0, i32 0}
!11 = !{!"air.compile.denorms_disable"}
!12 = !{!"air.compile.fast_math_enable"}
!13 = !{!"air.compile.framebuffer_fetch_enable"}
!14 = !{ptr @vsUshortICB, !15, !16}
!15 = !{}
!16 = !{!17, !30, !34}
!17 = !{i32 0, !"air.indirect_buffer", !"air.location_index", i32 0, i32 1, !"air.read", !"air.address_space", i32 1, !"air.struct_type_info", !18, !"air.arg_type_size", i32 56, !"air.arg_type_align_size", i32 8, !"air.arg_type_name", !"IndexDataUshort", !"air.arg_name", !"indexData"}
!18 = !{i32 0, i32 8, i32 0, !"ulong", !"renderCommand", !"air.indirect_argument", !19, i32 8, i32 4, i32 0, !"uint", !"minVertexCount", !"air.indirect_argument", !20, i32 12, i32 4, i32 0, !"uint", !"minInstanceCount", !"air.indirect_argument", !21, i32 16, i32 8, i32 0, !"ushort", !"indexBuffer", !"air.indirect_argument", !22, i32 24, i32 4, i32 0, !"uint", !"indexBufferElementCountMinusOne", !"air.indirect_argument", !23, i32 28, i32 4, i32 0, !"uint", !"indexCount", !"air.indirect_argument", !24, i32 32, i32 4, i32 0, !"uint", !"instanceCount", !"air.indirect_argument", !25, i32 36, i32 4, i32 0, !"uint", !"firstIndex", !"air.indirect_argument", !26, i32 40, i32 4, i32 0, !"uint", !"baseVertex", !"air.indirect_argument", !27, i32 44, i32 4, i32 0, !"uint", !"baseInstance", !"air.indirect_argument", !28, i32 48, i32 4, i32 0, !"int", !"primitiveType", !"air.indirect_argument", !29}
!19 = !{i32 0, !"air.indirect_constant", !"air.location_index", i32 0, i32 1, !"air.arg_type_name", !"ulong", !"air.arg_name", !"renderCommand"}
!20 = !{i32 1, !"air.indirect_constant", !"air.location_index", i32 1, i32 1, !"air.arg_type_name", !"uint", !"air.arg_name", !"minVertexCount"}
!21 = !{i32 2, !"air.indirect_constant", !"air.location_index", i32 2, i32 1, !"air.arg_type_name", !"uint", !"air.arg_name", !"minInstanceCount"}
!22 = !{i32 3, !"air.buffer", !"air.location_index", i32 3, i32 1, !"air.read_write", !"air.address_space", i32 1, !"air.arg_type_size", i32 2, !"air.arg_type_align_size", i32 2, !"air.arg_type_name", !"ushort", !"air.arg_name", !"indexBuffer"}
!23 = !{i32 4, !"air.indirect_constant", !"air.location_index", i32 4, i32 1, !"air.arg_type_name", !"uint", !"air.arg_name", !"indexBufferElementCountMinusOne"}
!24 = !{i32 5, !"air.indirect_constant", !"air.location_index", i32 5, i32 1, !"air.arg_type_name", !"uint", !"air.arg_name", !"indexCount"}
!25 = !{i32 6, !"air.indirect_constant", !"air.location_index", i32 6, i32 1, !"air.arg_type_name", !"uint", !"air.arg_name", !"instanceCount"}
!26 = !{i32 7, !"air.indirect_constant", !"air.location_index", i32 7, i32 1, !"air.arg_type_name", !"uint", !"air.arg_name", !"firstIndex"}
!27 = !{i32 8, !"air.indirect_constant", !"air.location_index", i32 8, i32 1, !"air.arg_type_name", !"uint", !"air.arg_name", !"baseVertex"}
!28 = !{i32 9, !"air.indirect_constant", !"air.location_index", i32 9, i32 1, !"air.arg_type_name", !"uint", !"air.arg_name", !"baseInstance"}
!29 = !{i32 10, !"air.indirect_constant", !"air.location_index", i32 10, i32 1, !"air.arg_type_name", !"int", !"air.arg_name", !"primitiveType"}
!30 = !{i32 1, !"air.indirect_buffer", !"air.location_index", i32 1, i32 1, !"air.read_write", !"air.address_space", i32 1, !"air.struct_type_info", !31, !"air.arg_type_size", i32 16, !"air.arg_type_align_size", i32 8, !"air.arg_type_name", !"ICBContainer", !"air.arg_name", !"icb_container"}
!31 = !{i32 0, i32 8, i32 0, !"uint", !"outOfBoundsRead", !"air.indirect_argument", !32, i32 8, i32 8, i32 0, !"command_buffer", !"commandBuffer", !"air.indirect_argument", !33}
!32 = !{i32 0, !"air.buffer", !"air.location_index", i32 0, i32 1, !"air.read_write", !"air.address_space", i32 1, !"air.arg_type_size", i32 4, !"air.arg_type_align_size", i32 4, !"air.arg_type_name", !"uint", !"air.arg_name", !"outOfBoundsRead"}
!33 = !{i32 1, !"air.command_buffer", !"air.location_index", i32 1, i32 1, !"air.arg_type_name", !"command_buffer", !"air.arg_name", !"commandBuffer"}
!34 = !{i32 2, !"air.vertex_id", !"air.arg_type_name", !"uint", !"air.arg_name", !"indexId"}
