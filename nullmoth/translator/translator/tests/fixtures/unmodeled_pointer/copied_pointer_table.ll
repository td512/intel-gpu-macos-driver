; A private table of pointers into two different buffers, copied from another table and advanced in place (the shape
; of MPS's LSTM kernels). The emitter has no model for the loaded row pointer; the read through it was a constant
; zero (OpCopyObject of OpConstantNull feeding the sum) and is refused now.
target datalayout = "e-p:64:64:64-i1:8:8-i8:8:8-i16:16:16-i32:32:32-i64:64:64-f32:32:32-f64:64:64-v16:16:16-v24:32:32-v32:32:32-v48:64:64-v64:64:64-v96:128:128-v128:128:128-v192:256:256-v256:256:256-v512:512:512-v1024:1024:1024-n8:16:32"
target triple = "air64_v28-apple-macosx26.7.0"

define void @pick(ptr addrspace(1) noundef readonly "air-buffer-no-alias" %a, ptr addrspace(1) noundef readonly "air-buffer-no-alias" %b, ptr addrspace(1) noundef "air-buffer-no-alias" %out, i32 noundef %gid) local_unnamed_addr #0 {
entry:
  %first = alloca [2 x ptr addrspace(1)], align 8
  %table = alloca [2 x ptr addrspace(1)], align 8
  %f0 = getelementptr inbounds [2 x ptr addrspace(1)], ptr %first, i64 0, i64 0
  store ptr addrspace(1) %a, ptr %f0, align 8
  %f1 = getelementptr inbounds [2 x ptr addrspace(1)], ptr %first, i64 0, i64 1
  store ptr addrspace(1) %b, ptr %f1, align 8
  br label %copy

copy:
  %c = phi i32 [ 0, %entry ], [ %cn, %copy ]
  %c64 = zext i32 %c to i64
  %from = getelementptr inbounds [2 x ptr addrspace(1)], ptr %first, i64 0, i64 %c64
  %p = load ptr addrspace(1), ptr %from, align 8
  %to = getelementptr inbounds [2 x ptr addrspace(1)], ptr %table, i64 0, i64 %c64
  store ptr addrspace(1) %p, ptr %to, align 8
  %cn = add nuw nsw i32 %c, 1
  %cd = icmp eq i32 %cn, 2
  br i1 %cd, label %loop, label %copy

loop:
  %i = phi i32 [ 0, %copy ], [ %next, %loop ]
  %sum = phi float [ 0.000000e+00, %copy ], [ %acc, %loop ]
  %bit = and i32 %i, 1
  %index = zext i32 %bit to i64
  %slot = getelementptr inbounds [2 x ptr addrspace(1)], ptr %table, i64 0, i64 %index
  %row = load ptr addrspace(1), ptr %slot, align 8
  %value = load float, ptr addrspace(1) %row, align 4
  %step = getelementptr inbounds float, ptr addrspace(1) %row, i64 1
  store ptr addrspace(1) %step, ptr %slot, align 8
  %acc = fadd float %sum, %value
  %next = add nuw nsw i32 %i, 1
  %done = icmp eq i32 %next, 4
  br i1 %done, label %exit, label %loop

exit:
  %gid64 = zext i32 %gid to i64
  %dst = getelementptr inbounds float, ptr addrspace(1) %out, i64 %gid64
  store float %acc, ptr addrspace(1) %dst, align 4
  ret void
}

attributes #0 = { convergent mustprogress nounwind willreturn }

!air.kernel = !{!0}
!air.version = !{!7}
!air.language_version = !{!8}

!0 = !{ptr @pick, !1, !2}
!1 = !{}
!2 = !{!3, !4, !5, !6}
!3 = !{i32 0, !"air.buffer", !"air.location_index", i32 0, i32 1, !"air.read", !"air.address_space", i32 1, !"air.arg_type_size", i32 4, !"air.arg_type_align_size", i32 4, !"air.arg_type_name", !"float", !"air.arg_name", !"a"}
!4 = !{i32 1, !"air.buffer", !"air.location_index", i32 1, i32 1, !"air.read", !"air.address_space", i32 1, !"air.arg_type_size", i32 4, !"air.arg_type_align_size", i32 4, !"air.arg_type_name", !"float", !"air.arg_name", !"b"}
!5 = !{i32 2, !"air.buffer", !"air.location_index", i32 2, i32 1, !"air.read_write", !"air.address_space", i32 1, !"air.arg_type_size", i32 4, !"air.arg_type_align_size", i32 4, !"air.arg_type_name", !"float", !"air.arg_name", !"out"}
!6 = !{i32 3, !"air.thread_position_in_grid", !"air.arg_type_name", !"uint", !"air.arg_name", !"gid"}
!7 = !{i32 2, i32 8, i32 0}
!8 = !{!"Metal", i32 4, i32 0, i32 0}
