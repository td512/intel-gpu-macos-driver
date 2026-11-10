; A Metal kernel whose threadgroup parameter is a struct holding one metal::array (threadgroup TG &tg [[threadgroup(0)]]),
; zeroed whole (tg = TG{}: an llvm.memset of 256 bytes), then indexed. WebKit zero-initialises WGSL var<workgroup> this
; way; every such compute shader was refused (the Store of the struct null hit the Workgroup array the parameter
; becomes). Compiled from user source by Apple's Metal compiler on the B580 test machine (tgprobe, 11 Nov 2026).
; ModuleID = 'nvmtl-air'
source_filename = "zero_arg"
target datalayout = "e-p:64:64:64-i1:8:8-i8:8:8-i16:16:16-i32:32:32-i64:64:64-f32:32:32-f64:64:64-v16:16:16-v24:32:32-v32:32:32-v48:64:64-v64:64:64-v96:128:128-v128:128:128-v192:256:256-v256:256:256-v512:512:512-v1024:1024:1024-n8:16:32"
target triple = "air64_v28-apple-macosx26.7.0"

%struct.TG = type { %"struct.metal::array" }
%"struct.metal::array" = type { [64 x i32] }

; Function Attrs: convergent mustprogress nounwind willreturn
define void @zero_arg(ptr addrspace(1) noundef writeonly captures(none) "air-buffer-no-alias" %s, ptr addrspace(3) noundef align 4 captures(none) dereferenceable(256) "air-buffer-no-alias" %tg, i32 noundef %l) local_unnamed_addr #0 {
entry:
  %cmp = icmp eq i32 %l, 0
  br i1 %cmp, label %if.then, label %if.end

if.then:                                          ; preds = %entry
  %ref.tmp.sroa.0.0..sroa_cast = bitcast ptr addrspace(3) %tg to ptr addrspace(3)
  call void @llvm.memset.p3.i64(ptr addrspace(3) noundef align 4 dereferenceable(256) %ref.tmp.sroa.0.0..sroa_cast, i8 0, i64 256, i1 false)
  br label %if.end

if.end:                                           ; preds = %if.then, %entry
  tail call void @air.wg.barrier(i32 2, i32 1) #3
  %conv = zext i32 %l to i64
  %arrayidx.i18 = getelementptr inbounds %struct.TG, ptr addrspace(3) %tg, i64 0, i32 0, i32 0, i64 %conv
  %0 = load i32, ptr addrspace(3) %arrayidx.i18, align 4, !tbaa !22, !alias.scope !26, !noalias !29
  %add = add i32 %0, %l
  store i32 %add, ptr addrspace(3) %arrayidx.i18, align 4, !tbaa !22, !alias.scope !26, !noalias !29
  tail call void @air.wg.barrier(i32 2, i32 1) #3
  br i1 %cmp, label %if.then2, label %if.end5

if.then2:                                         ; preds = %if.end
  %arrayidx.i = getelementptr inbounds %struct.TG, ptr addrspace(3) %tg, i64 0, i32 0, i32 0, i64 63
  %1 = load i32, ptr addrspace(3) %arrayidx.i, align 4, !tbaa !22, !alias.scope !26, !noalias !29
  store i32 %1, ptr addrspace(1) %s, align 4, !tbaa !22, !alias.scope !29, !noalias !26
  br label %if.end5

if.end5:                                          ; preds = %if.then2, %if.end
  ret void
}

; Function Attrs: convergent mustprogress nounwind willreturn
declare void @air.wg.barrier(i32, i32) local_unnamed_addr #1

; Function Attrs: nocallback nofree nounwind willreturn memory(argmem: write)
declare void @llvm.memset.p3.i64(ptr addrspace(3) writeonly captures(none), i8, i64, i1 immarg) #2

attributes #0 = { convergent mustprogress nounwind willreturn "approx-func-fp-math"="true" "frame-pointer"="all" "min-legal-vector-width"="0" "no-builtins" "no-infs-fp-math"="true" "no-nans-fp-math"="true" "no-signed-zeros-fp-math"="true" "no-trapping-math"="true" "stack-protector-buffer-size"="8" "unsafe-fp-math"="true" }
attributes #1 = { convergent mustprogress nounwind willreturn }
attributes #2 = { nocallback nofree nounwind willreturn memory(argmem: write) }
attributes #3 = { convergent nounwind willreturn }

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
!12 = !{!"air.compile.fast_math_enable"}
!13 = !{!"air.compile.framebuffer_fetch_enable"}
!14 = !{ptr @zero_arg, !15, !16}
!15 = !{}
!16 = !{!17, !18, !21}
!17 = !{i32 0, !"air.buffer", !"air.location_index", i32 0, i32 1, !"air.read_write", !"air.address_space", i32 1, !"air.arg_type_size", i32 4, !"air.arg_type_align_size", i32 4, !"air.arg_type_name", !"uint", !"air.arg_name", !"s"}
!18 = !{i32 1, !"air.buffer", !"air.buffer_size", i32 256, !"air.location_index", i32 0, i32 1, !"air.read_write", !"air.address_space", i32 3, !"air.struct_type_info", !19, !"air.arg_type_size", i32 256, !"air.arg_type_align_size", i32 4, !"air.arg_type_name", !"TG", !"air.arg_name", !"tg"}
!19 = !{!"air.struct_type_info", !20, i32 0, i32 256, i32 0, !"metal::array", !"part"}
!20 = !{i32 0, i32 4, i32 64, !"uint", !"__elems"}
!21 = !{i32 2, !"air.thread_index_in_threadgroup", !"air.arg_type_name", !"uint", !"air.arg_name", !"l"}
!22 = !{!23, !23, i64 0}
!23 = !{!"int", !24, i64 0}
!24 = !{!"omnipotent char", !25, i64 0}
!25 = !{!"Simple C++ TBAA"}
!26 = !{!27}
!27 = distinct !{!27, !28, !"air-alias-scope-arg(1)"}
!28 = distinct !{!28, !"air-alias-scopes(zero_arg)"}
!29 = !{!30}
!30 = distinct !{!30, !28, !"air-alias-scope-arg(0)"}
