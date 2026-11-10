; Safari's WebGPU (WebKit's WGSL compiler, then Apple's Metal compiler), on the B580 test machine, 11 Nov 2026: a compute
; shader with a var<workgroup> array<u32, 64>. WebKit zero-initialises it with __wgslZeroWorkgroupVar, which stores 0 one
; byte at a time through a uchar pointer into each u32 word (one invocation, then a barrier). The byte view of a
; Workgroup word could not be expressed and every such shader was refused (createComputePipeline failed).
; ModuleID = 'nvmtl-air'
source_filename = "function0"
target datalayout = "e-p:64:64:64-i1:8:8-i8:8:8-i16:16:16-i32:32:32-i64:64:64-f32:32:32-f64:64:64-v16:16:16-v24:32:32-v32:32:32-v48:64:64-v64:64:64-v96:128:128-v128:128:128-v192:256:256-v256:256:256-v512:512:512-v1024:1024:1024-n8:16:32"
target triple = "air64_v28-apple-macosx26.7.0"

%"struct.metal::array.0" = type { [64 x i32] }
%struct.__ArgumentBufferT_0_0 = type <{ ptr addrspace(1), i32, [4 x i8] }>
%"struct.metal::array" = type { [1 x i32] }

@_ZZ9function0jRU11MTLconstantK21__ArgumentBufferT_0_0E7global1 = internal unnamed_addr addrspace(3) global %"struct.metal::array.0" zeroinitializer, align 4

; Function Attrs: convergent mustprogress nounwind
define void @function0(i32 noundef %parameter0, ptr addrspace(2) noundef readonly align 8 captures(none) dereferenceable(12) "air-buffer-no-alias" %__ArgumentBuffer_0) local_unnamed_addr #0 {
entry:
  %cmp = icmp eq i32 %parameter0, 0
  br i1 %cmp, label %for.body, label %if.end

for.body:                                         ; preds = %_ZL22__wgslZeroWorkgroupVarIjEvRU14MTLthreadgroupT_.exit, %entry
  %__i0.028 = phi i32 [ %add, %_ZL22__wgslZeroWorkgroupVarIjEvRU14MTLthreadgroupT_.exit ], [ 0, %entry ]
  %conv = zext i32 %__i0.028 to i64
  %arrayidx.i24 = getelementptr inbounds %"struct.metal::array.0", ptr addrspace(3) @_ZZ9function0jRU11MTLconstantK21__ArgumentBufferT_0_0E7global1, i64 0, i32 0, i64 %conv
  %0 = bitcast ptr addrspace(3) %arrayidx.i24 to ptr addrspace(3)
  br label %for.body.i

for.body.i:                                       ; preds = %for.body.i, %for.body
  %i.05.i = phi i32 [ 0, %for.body ], [ %inc.i, %for.body.i ]
  %conv.i = zext i32 %i.05.i to i64
  %arrayidx.i27 = getelementptr inbounds i8, ptr addrspace(3) %0, i64 %conv.i
  store i8 0, ptr addrspace(3) %arrayidx.i27, align 1, !tbaa !23
  %inc.i = add nuw nsw i32 %i.05.i, 1
  %exitcond.not.i = icmp eq i32 %inc.i, 4
  br i1 %exitcond.not.i, label %_ZL22__wgslZeroWorkgroupVarIjEvRU14MTLthreadgroupT_.exit, label %for.body.i, !llvm.loop !26

_ZL22__wgslZeroWorkgroupVarIjEvRU14MTLthreadgroupT_.exit: ; preds = %for.body.i
  %add = add nuw nsw i32 %__i0.028, 1
  %exitcond.not = icmp eq i32 %add, 64
  br i1 %exitcond.not, label %if.end, label %for.body, !llvm.loop !28

if.end:                                           ; preds = %_ZL22__wgslZeroWorkgroupVarIjEvRU14MTLthreadgroupT_.exit, %entry
  tail call void @air.wg.barrier(i32 2, i32 1) #3
  %global02 = getelementptr inbounds %struct.__ArgumentBufferT_0_0, ptr addrspace(2) %__ArgumentBuffer_0, i64 0, i32 0
  %1 = load ptr addrspace(1), ptr addrspace(2) %global02, align 8, !tbaa !29, !alias.scope !33
  %__global0_ArrayLength3 = getelementptr inbounds %struct.__ArgumentBufferT_0_0, ptr addrspace(2) %__ArgumentBuffer_0, i64 0, i32 1
  %2 = load i32, ptr addrspace(2) %__global0_ArrayLength3, align 8, !tbaa !36, !alias.scope !33
  %3 = tail call i32 @air.min.u.i32(i32 %parameter0, i32 63) #4
  %conv5 = zext i32 %3 to i64
  %arrayidx.i = getelementptr inbounds %"struct.metal::array.0", ptr addrspace(3) @_ZZ9function0jRU11MTLconstantK21__ArgumentBufferT_0_0E7global1, i64 0, i32 0, i64 %conv5
  store i32 %parameter0, ptr addrspace(3) %arrayidx.i, align 4, !tbaa !37
  tail call void @air.wg.barrier(i32 2, i32 1) #3
  br i1 %cmp, label %if.then8, label %if.end14

if.then8:                                         ; preds = %if.end
  %4 = load i32, ptr addrspace(3) getelementptr inbounds (%"struct.metal::array.0", ptr addrspace(3) @_ZZ9function0jRU11MTLconstantK21__ArgumentBufferT_0_0E7global1, i64 0, i32 0, i64 63), align 4, !tbaa !37
  %div1.i = lshr i32 %2, 2
  %sub = add nsw i32 %div1.i, -1
  %5 = tail call i32 @air.min.u.i32(i32 0, i32 %sub) #4
  %conv12 = zext i32 %5 to i64
  %arrayidx.i26 = getelementptr inbounds %"struct.metal::array", ptr addrspace(1) %1, i64 0, i32 0, i64 %conv12
  store i32 %4, ptr addrspace(1) %arrayidx.i26, align 4, !tbaa !37
  br label %if.end14

if.end14:                                         ; preds = %if.then8, %if.end
  ret void
}

; Function Attrs: mustprogress nofree nosync nounwind willreturn memory(none)
declare i32 @air.min.u.i32(i32, i32) local_unnamed_addr #1

; Function Attrs: convergent mustprogress nounwind willreturn
declare void @air.wg.barrier(i32, i32) local_unnamed_addr #2

attributes #0 = { convergent mustprogress nounwind "approx-func-fp-math"="true" "frame-pointer"="all" "min-legal-vector-width"="0" "no-builtins" "no-signed-zeros-fp-math"="true" "no-trapping-math"="true" "stack-protector-buffer-size"="8" "unsafe-fp-math"="true" }
attributes #1 = { mustprogress nofree nosync nounwind willreturn memory(none) }
attributes #2 = { convergent mustprogress nounwind willreturn }
attributes #3 = { convergent nounwind willreturn }
attributes #4 = { nounwind willreturn memory(none) }

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
!8 = !{!"Apple metal version 32023.886 (metalfe-32023.886.1)"}
!9 = !{i32 2, i32 8, i32 0}
!10 = !{!"Metal", i32 4, i32 0, i32 0}
!11 = !{!"air.compile.denorms_disable"}
!12 = !{!"air.compile.fast_math_disable"}
!13 = !{!"air.compile.framebuffer_fetch_enable"}
!14 = !{ptr @function0, !15, !16}
!15 = !{}
!16 = !{!17, !18}
!17 = !{i32 0, !"air.thread_index_in_threadgroup", !"air.arg_type_name", !"uint", !"air.arg_name", !"parameter0"}
!18 = !{i32 1, !"air.indirect_buffer", !"air.buffer_size", i32 16, !"air.location_index", i32 0, i32 1, !"air.read", !"air.address_space", i32 2, !"air.struct_type_info", !19, !"air.arg_type_size", i32 16, !"air.arg_type_align_size", i32 8, !"air.arg_type_name", !"__ArgumentBufferT_0_0", !"air.arg_name", !"__ArgumentBuffer_0"}
!19 = !{i32 0, i32 8, i32 0, !"metal::array", !"global0", !"air.indirect_argument", !20, i32 8, i32 4, i32 0, !"uint", !"__global0_ArrayLength", !"air.indirect_argument", !22}
!20 = !{i32 0, !"air.buffer", !"air.buffer_size", i32 4, !"air.location_index", i32 0, i32 1, !"air.read_write", !"air.address_space", i32 1, !"air.struct_type_info", !21, !"air.arg_type_size", i32 4, !"air.arg_type_align_size", i32 4, !"air.arg_type_name", !"metal::array", !"air.arg_name", !"global0"}
!21 = !{i32 0, i32 4, i32 1, !"uint", !"__elems"}
!22 = !{i32 1, !"air.indirect_constant", !"air.location_index", i32 1, i32 1, !"air.arg_type_name", !"uint", !"air.arg_name", !"__global0_ArrayLength"}
!23 = !{!24, !24, i64 0}
!24 = !{!"omnipotent char", !25, i64 0}
!25 = !{!"Simple C++ TBAA"}
!26 = distinct !{!26, !27}
!27 = !{!"llvm.loop.mustprogress"}
!28 = distinct !{!28, !27}
!29 = !{!30, !31, i64 0}
!30 = !{!"_ZTS21__ArgumentBufferT_0_0", !31, i64 0, !32, i64 8}
!31 = !{!"any pointer", !24, i64 0}
!32 = !{!"int", !24, i64 0}
!33 = !{!34}
!34 = distinct !{!34, !35, !"air-alias-scope-arg(1)"}
!35 = distinct !{!35, !"air-alias-scopes(function0)"}
!36 = !{!30, !32, i64 8}
!37 = !{!32, !32, i64 0}
