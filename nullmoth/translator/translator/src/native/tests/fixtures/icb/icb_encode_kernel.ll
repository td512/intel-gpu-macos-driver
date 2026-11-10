; ModuleID = 'nvmtl-air'
; icb_encode_kernel: AIR as the Metal plugin hands it to the translator (tbaa and alias-scope metadata removed)
source_filename = "encode"
target datalayout = "e-p:64:64:64-i1:8:8-i8:8:8-i16:16:16-i32:32:32-i64:64:64-f32:32:32-f64:64:64-v16:16:16-v24:32:32-v32:32:32-v48:64:64-v64:64:64-v96:128:128-v128:128:128-v192:256:256-v256:256:256-v512:512:512-v1024:1024:1024-n8:16:32"
target triple = "air64_v29-apple-macosx27.0.0"

%struct.Container = type { %"struct.metal::command_buffer" }
%"struct.metal::command_buffer" = type { ptr addrspace(1) }

; Function Attrs: mustprogress nounwind willreturn
define void @encode(ptr addrspace(1) noundef readonly captures(none) "air-buffer-no-alias" %c, ptr addrspace(1) noundef "air-buffer-no-alias" %ib32, ptr addrspace(1) noundef "air-buffer-no-alias" %ib16, i32 noundef %t) local_unnamed_addr #0 {
entry:
  %cmp.not = icmp eq i32 %t, 0
  br i1 %cmp.not, label %if.end, label %return

if.end:                                           ; preds = %entry
  %agg.tmp.sroa.0.0..sroa_idx = getelementptr inbounds %struct.Container, ptr addrspace(1) %c, i64 0, i32 0, i32 0
  %agg.tmp.sroa.0.0.copyload = load ptr addrspace(1), ptr addrspace(1) %agg.tmp.sroa.0.0..sroa_idx, align 8
  tail call void @air.draw_primitives_render_command(ptr addrspace(1) captures(none) %agg.tmp.sroa.0.0.copyload, i32 0, i32 3, i32 16, i32 6, i32 1, i32 0) #2
  %agg.tmp1.sroa.0.0.copyload = load ptr addrspace(1), ptr addrspace(1) %agg.tmp.sroa.0.0..sroa_idx, align 8
  %add.ptr = getelementptr inbounds i32, ptr addrspace(1) %ib32, i64 6
  tail call void @air.draw_indexed_primitives_render_command.p1i32(ptr addrspace(1) captures(none) %agg.tmp1.sroa.0.0.copyload, i32 1, i32 3, i32 6, ptr addrspace(1) %add.ptr, i32 1, i32 4, i32 1) #2
  %agg.tmp3.sroa.0.0.copyload = load ptr addrspace(1), ptr addrspace(1) %agg.tmp.sroa.0.0..sroa_idx, align 8
  %add.ptr5 = getelementptr inbounds i16, ptr addrspace(1) %ib16, i64 6
  tail call void @air.draw_indexed_primitives_render_command.p1i16(ptr addrspace(1) captures(none) %agg.tmp3.sroa.0.0.copyload, i32 2, i32 3, i32 6, ptr addrspace(1) %add.ptr5, i32 1, i32 8, i32 2) #2
  %agg.tmp6.sroa.0.0.copyload = load ptr addrspace(1), ptr addrspace(1) %agg.tmp.sroa.0.0..sroa_idx, align 8
  tail call void @air.reset_render_command(ptr addrspace(1) captures(none) %agg.tmp6.sroa.0.0.copyload, i32 5) #2
  br label %return

return:                                           ; preds = %if.end, %entry
  ret void
}

; Function Attrs: mustprogress nounwind willreturn
declare void @air.reset_render_command(ptr addrspace(1) captures(none), i32) local_unnamed_addr #1

; Function Attrs: mustprogress nounwind willreturn
declare void @air.draw_indexed_primitives_render_command.p1i16(ptr addrspace(1) captures(none), i32, i32, i32, ptr addrspace(1), i32, i32, i32) local_unnamed_addr #1

; Function Attrs: mustprogress nounwind willreturn
declare void @air.draw_indexed_primitives_render_command.p1i32(ptr addrspace(1) captures(none), i32, i32, i32, ptr addrspace(1), i32, i32, i32) local_unnamed_addr #1

; Function Attrs: mustprogress nounwind willreturn
declare void @air.draw_primitives_render_command(ptr addrspace(1) captures(none), i32, i32, i32, i32, i32, i32) local_unnamed_addr #1

attributes #0 = { mustprogress nounwind willreturn "approx-func-fp-math"="true" "frame-pointer"="all" "min-legal-vector-width"="0" "no-builtins" "no-infs-fp-math"="true" "no-nans-fp-math"="true" "no-signed-zeros-fp-math"="true" "no-trapping-math"="true" "stack-protector-buffer-size"="8" "unsafe-fp-math"="true" }
attributes #1 = { mustprogress nounwind willreturn }
attributes #2 = { nounwind willreturn }

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
!14 = !{ptr @encode, !15, !16}
!15 = !{}
!16 = !{!17, !20, !21, !22}
!17 = !{i32 0, !"air.indirect_buffer", !"air.location_index", i32 0, i32 1, !"air.read_write", !"air.address_space", i32 1, !"air.struct_type_info", !18, !"air.arg_type_size", i32 8, !"air.arg_type_align_size", i32 8, !"air.arg_type_name", !"Container", !"air.arg_name", !"c"}
!18 = !{i32 0, i32 8, i32 0, !"command_buffer", !"cb", !"air.indirect_argument", !19}
!19 = !{i32 0, !"air.command_buffer", !"air.location_index", i32 0, i32 1, !"air.arg_type_name", !"command_buffer", !"air.arg_name", !"cb"}
!20 = !{i32 1, !"air.buffer", !"air.location_index", i32 1, i32 1, !"air.read_write", !"air.address_space", i32 1, !"air.arg_type_size", i32 4, !"air.arg_type_align_size", i32 4, !"air.arg_type_name", !"uint", !"air.arg_name", !"ib32"}
!21 = !{i32 2, !"air.buffer", !"air.location_index", i32 2, i32 1, !"air.read_write", !"air.address_space", i32 1, !"air.arg_type_size", i32 2, !"air.arg_type_align_size", i32 2, !"air.arg_type_name", !"ushort", !"air.arg_name", !"ib16"}
!22 = !{i32 3, !"air.thread_position_in_grid", !"air.arg_type_name", !"uint", !"air.arg_name", !"t"}
