(W)     mov (16|M0)              r127.0<1>:ud  0x0:ud                             
(W)     and (1|M0)               r127.2<1>:ud  r0.0<0;1,0>:ud    0xFFFFFFC0:ud             
(W)     and (1|M0)               r127.0<1>:uw  r0.4<0;1,0>:uw    0xFF:uw             
(W)     add (1|M0)               r127.2<1>:ud  r127.2<0;1,0>:ud  0x40:ud              {I@2}
(W)     add (1|M0)               r127.2<1>:ud  r127.2<0;1,0>:ud  0x0:ud              {I@1}
(W)     mad (1|M0)               r127.0<1>:ud  r127.2<0;0>:ud    r127.0<0;0>:uw    0x40:uw              {I@1}
(W)     mov (8|M0)               r2.0<1>:ud    r1.0<1;1,0>:ud                  
(W)     send.ugm (1|M0)          r1       r127  null:0  0xFF000000            0x6219D500           {A@1,$0} // wr:1+0, rd:1; load.ugm.d32x16t.a32.ca.cc.bti[255]
(W)     and (1|M0)               r127.0<1>:ud  r0.0<0;1,0>:ud    0xFFFFFFC0:ud              {$0.src}
(W)     add (1|M0)               r127.0<1>:ud  r127.0<0;1,0>:ud  0x0:ud              {I@1}
(W)     send.ugm (1|M0)          r3       r127  null:0  0xFF000000            0x6219D500           {I@1,$1} // wr:1+0, rd:1; load.ugm.d32x16t.a32.ca.cc.bti[255]
(W)     mov (16|M0)              r4.0<1>:ud    r0.0<1;1,0>:ud                  
(W)     or (1|M0)                cr0.0<1>:ud   cr0.0<0;1,0>:ud   0x400004C0:ud              {A@1}
(W)     mul (1|M0)               acc0.0<1>:d   r2.3<0;1,0>:d     r4.2<0;1,0>:uw   {A@1}
        mov (32|M0)              r8.0<1>:d     r1.0<1;1,0>:uw                   {$0.dst}
(W)     macl (1|M0)              r5.0<1>:d     r2.3<0;1,0>:d     r4.1<0;1,0>:d    {Compacted}
        add3 (32|M0)             r6.0<1>:d     r5.0<0;0>:d       r8.0<1;0>:d       r2.0<0>:d        {Compacted,I@1}
        cmp (32|M0)   (lt)f0.0   null<1>:d     r6.0<1;1,0>:d     r3.2<0;1,0>:d    {@1,$1.dst}
(f0.0)  goto (32|M0)                         48                  48                
        mov (32|M0)              r10.0<1>:ud   0x0:ud                             
        goto (32|M0)                         16                  184                
        join (32|M0)                         168                                
        mov (32|M0)              r10.0<1>:ud   0x0:ud                              {Compacted}
        mov (16|M0)              r91.0<2>:ud   r6.0<1;1,0>:ud                   {Compacted}
        mov (16|M16)             r93.0<2>:ud   r7.0<1;1,0>:ud                  
        shl (16|M0)              r95.0<1>:q    r91.0<2;1,0>:d    2:w               {I@2}
        shl (16|M16)             r97.0<1>:q    r93.0<2;1,0>:d    2:w               {I@2}
        add (16|M0)              r12.0<1>:q    r95.0<1;1,0>:q    r2.3<0;1,0>:q    {Compacted,I@2}
        add (16|M16)             r14.0<1>:q    r97.0<1;1,0>:q    r2.3<0;1,0>:q    {Compacted,I@2}
        send.ugm (32|M0)         r16      r12  null:0  0x0            0x08200580           {I@1,$2} // wr:4+0, rd:2; load.ugm.d32.a64
        add (32|M0)              r6.0<1>:d     r6.0<1;1,0>:d     r3.6<0;1,0>:d   
        cmp (32|M0)   (lt)f3.0   null<1>:d     r6.0<1;1,0>:d     r3.2<0;1,0>:d    {I@1}
        add (32|M0)              r10.0<1>:f    r10.0<1;1,0>:f    r16.0<1;1,0>:f   {Compacted,$2.dst}
(f3.0)  goto.b (32|M0)                       16                  -128                
        join (32|M0)                         16                                
        shl (32|M0)              r18.0<1>:d    r8.0<1;1,0>:d     2:w               {Compacted}
        send.slm (32|M0)         null     r18  r10:2  0x0            0x04000504           {A@1,$3} // wr:2+2, rd:0; store.slm.d32.a32
(W)     send.slm (1|M0)          r20      r4  null:0  0x0            0x0210001F           {$4} // wr:1+0, rd:1; fence.slm.none.group
(W)     mov (1|M0)               r21.2<1>:f    3.58732e-43:f                              
(W)     mov (2|M0)               r21.10<1>:ub  r4.11<0;1,0>:ub                  {F@1}
(W)     mov (8|M0)               null<1>:ud    r20.0<1;1,0>:ud                  {$4.dst}
(W)     send.gtwy (1|M0)         null     r21  null:0  0x0            0x02000004           {I@2,$5} // wr:1+0, rd:0; signal barrier
(W)     sync.bar                             0x0                                
        cmp (32|M0)   (lt)f2.0   null<2>:uw    r1.0<1;1,0>:uw    0x80:uw             
(~f2.0) goto (32|M0)                         80                  80                
        send.slm (32|M0)         r22      r18  null:0  0x200000            0x04200500           {$6} // wr:2+0, rd:2; load.slm.d32.a32.flat[A+0x200]
        send.slm (32|M0)         r24      r18  null:0  0x0            0x04200500           {$7} // wr:2+0, rd:2; load.slm.d32.a32
        sync.nop                             null                             {Compacted,$7.dst}
        add (32|M0)              r26.0<1>:f    r24.0<1;1,0>:f    r22.0<1;1,0>:f   {Compacted,$6.dst}
        send.slm (32|M0)         null     r18  r26:2  0x0            0x04000504           {F@1,$8} // wr:2+2, rd:0; store.slm.d32.a32
        join (32|M0)                         16                                
(W)     send.slm (1|M0)          r28      r4  null:0  0x0            0x0210001F           {$9} // wr:1+0, rd:1; fence.slm.none.group
(W)     mov (1|M0)               r29.2<1>:f    3.58732e-43:f                              
(W)     mov (2|M0)               r29.10<1>:ub  r4.11<0;1,0>:ub                  {F@1}
(W)     mov (8|M0)               null<1>:ud    r28.0<1;1,0>:ud                  {$9.dst}
(W)     send.gtwy (1|M0)         null     r29  null:0  0x0            0x02000004           {I@2,$10} // wr:1+0, rd:0; signal barrier
(W)     sync.bar                             0x0                                
        cmp (32|M0)   (lt)f1.0   null<2>:uw    r1.0<1;1,0>:uw    0x40:uw             
(~f1.0) goto (32|M0)                         80                  80                
        send.slm (32|M0)         r30      r18  null:0  0x100000            0x04200500           {$11} // wr:2+0, rd:2; load.slm.d32.a32.flat[A+0x100]
        send.slm (32|M0)         r32      r18  null:0  0x0            0x04200500           {$12} // wr:2+0, rd:2; load.slm.d32.a32
        sync.nop                             null                             {Compacted,$12.dst}
        add (32|M0)              r34.0<1>:f    r32.0<1;1,0>:f    r30.0<1;1,0>:f   {Compacted,$11.dst}
        send.slm (32|M0)         null     r18  r34:2  0x0            0x04000504           {F@1,$13} // wr:2+2, rd:0; store.slm.d32.a32
        join (32|M0)                         16                                
(W)     send.slm (1|M0)          r36      r4  null:0  0x0            0x0210001F           {$14} // wr:1+0, rd:1; fence.slm.none.group
(W)     mov (1|M0)               r37.2<1>:f    3.58732e-43:f                              
(W)     mov (2|M0)               r37.10<1>:ub  r4.11<0;1,0>:ub                  {F@1}
(W)     mov (8|M0)               null<1>:ud    r36.0<1;1,0>:ud                  {$14.dst}
(W)     send.gtwy (1|M0)         null     r37  null:0  0x0            0x02000004           {I@2,$15} // wr:1+0, rd:0; signal barrier
(W)     sync.bar                             0x0                                
        cmp (32|M0)   (lt)f0.0   null<2>:uw    r1.0<1;1,0>:uw    0x20:uw             
(~f0.0) goto (32|M0)                         80                  80                
        send.slm (32|M0)         r38      r18  null:0  0x80000            0x04200500           {$0} // wr:2+0, rd:2; load.slm.d32.a32.flat[A+0x80]
        send.slm (32|M0)         r40      r18  null:0  0x0            0x04200500           {$1} // wr:2+0, rd:2; load.slm.d32.a32
        sync.nop                             null                             {Compacted,$1.dst}
        add (32|M0)              r42.0<1>:f    r40.0<1;1,0>:f    r38.0<1;1,0>:f   {Compacted,$0.dst}
        send.slm (32|M0)         null     r18  r42:2  0x0            0x04000504           {F@1,$2} // wr:2+2, rd:0; store.slm.d32.a32
        join (32|M0)                         16                                
(W)     send.slm (1|M0)          r44      r4  null:0  0x0            0x0210001F           {$4} // wr:1+0, rd:1; fence.slm.none.group
(W)     mov (1|M0)               r45.2<1>:f    3.58732e-43:f                              
(W)     mov (2|M0)               r45.10<1>:ub  r4.11<0;1,0>:ub                  {F@1}
(W)     mov (8|M0)               null<1>:ud    r44.0<1;1,0>:ud                  {$4.dst}
(W)     send.gtwy (1|M0)         null     r45  null:0  0x0            0x02000004           {I@2,$6} // wr:1+0, rd:0; signal barrier
(W)     sync.bar                             0x0                                
        cmp (32|M0)   (lt)f3.0   null<2>:uw    r1.0<1;1,0>:uw    0x10:uw             
(~f3.0) goto (32|M0)                         80                  80                
        send.slm (32|M0)         r46      r18  null:0  0x40000            0x04200500           {$7} // wr:2+0, rd:2; load.slm.d32.a32.flat[A+0x40]
        send.slm (32|M0)         r48      r18  null:0  0x0            0x04200500           {$9} // wr:2+0, rd:2; load.slm.d32.a32
        sync.nop                             null                             {Compacted,$9.dst}
        add (32|M0)              r50.0<1>:f    r48.0<1;1,0>:f    r46.0<1;1,0>:f   {Compacted,$7.dst}
        send.slm (32|M0)         null     r18  r50:2  0x0            0x04000504           {F@1,$11} // wr:2+2, rd:0; store.slm.d32.a32
        join (32|M0)                         16                                
(W)     send.slm (1|M0)          r52      r4  null:0  0x0            0x0210001F           {$12} // wr:1+0, rd:1; fence.slm.none.group
(W)     mov (1|M0)               r53.2<1>:f    3.58732e-43:f                              
(W)     mov (2|M0)               r53.10<1>:ub  r4.11<0;1,0>:ub                  {F@1}
(W)     mov (8|M0)               null<1>:ud    r52.0<1;1,0>:ud                  {$12.dst}
(W)     send.gtwy (1|M0)         null     r53  null:0  0x0            0x02000004           {I@2,$14} // wr:1+0, rd:0; signal barrier
(W)     sync.bar                             0x0                                
        cmp (32|M0)   (lt)f2.0   null<2>:uw    r1.0<1;1,0>:uw    0x8:uw             
(~f2.0) goto (32|M0)                         80                  80                
        send.slm (32|M0)         r54      r18  null:0  0x20000            0x04200500           {$0} // wr:2+0, rd:2; load.slm.d32.a32.flat[A+0x20]
        send.slm (32|M0)         r56      r18  null:0  0x0            0x04200500           {$1} // wr:2+0, rd:2; load.slm.d32.a32
        sync.nop                             null                             {Compacted,$1.dst}
        add (32|M0)              r58.0<1>:f    r56.0<1;1,0>:f    r54.0<1;1,0>:f   {Compacted,$0.dst}
        send.slm (32|M0)         null     r18  r58:2  0x0            0x04000504           {F@1,$4} // wr:2+2, rd:0; store.slm.d32.a32
        join (32|M0)                         16                                
(W)     send.slm (1|M0)          r60      r4  null:0  0x0            0x0210001F           {$7} // wr:1+0, rd:1; fence.slm.none.group
(W)     mov (1|M0)               r61.2<1>:f    3.58732e-43:f                              
(W)     mov (2|M0)               r61.10<1>:ub  r4.11<0;1,0>:ub                  {F@1}
(W)     mov (8|M0)               null<1>:ud    r60.0<1;1,0>:ud                  {$7.dst}
(W)     send.gtwy (1|M0)         null     r61  null:0  0x0            0x02000004           {I@2,$9} // wr:1+0, rd:0; signal barrier
(W)     sync.bar                             0x0                                
        cmp (32|M0)   (lt)f1.0   null<2>:uw    r1.0<1;1,0>:uw    0x4:uw             
(~f1.0) goto (32|M0)                         80                  80                
        send.slm (32|M0)         r62      r18  null:0  0x10000            0x04200500           {$12} // wr:2+0, rd:2; load.slm.d32.a32.flat[A+0x10]
        send.slm (32|M0)         r64      r18  null:0  0x0            0x04200500           {$0} // wr:2+0, rd:2; load.slm.d32.a32
        sync.nop                             null                             {Compacted,$0.dst}
        add (32|M0)              r66.0<1>:f    r64.0<1;1,0>:f    r62.0<1;1,0>:f   {Compacted,$12.dst}
        send.slm (32|M0)         null     r18  r66:2  0x0            0x04000504           {F@1,$1} // wr:2+2, rd:0; store.slm.d32.a32
        join (32|M0)                         16                                
(W)     send.slm (1|M0)          r68      r4  null:0  0x0            0x0210001F           {$7} // wr:1+0, rd:1; fence.slm.none.group
(W)     mov (1|M0)               r69.2<1>:f    3.58732e-43:f                              
(W)     mov (2|M0)               r69.10<1>:ub  r4.11<0;1,0>:ub                  {F@1}
(W)     mov (8|M0)               null<1>:ud    r68.0<1;1,0>:ud                  {$7.dst}
(W)     send.gtwy (1|M0)         null     r69  null:0  0x0            0x02000004           {I@2,$12} // wr:1+0, rd:0; signal barrier
(W)     sync.bar                             0x0                                
        cmp (32|M0)   (lt)f0.0   null<2>:uw    r1.0<1;1,0>:uw    0x2:uw             
(~f0.0) goto (32|M0)                         64                  64                
        send.slm (32|M0)         r70      r18  null:0  0x0            0x04602500           {$0} // wr:2+0, rd:6; load.slm.d32x3.a32
        add (32|M0)              r76.0<1>:f    r70.0<1;1,0>:f    r74.0<1;1,0>:f   {$0.dst}
        send.slm (32|M0)         null     r18  r76:2  0x0            0x04000504           {F@1,$7} // wr:2+2, rd:0; store.slm.d32.a32
        join (32|M0)                         16                                
(W)     send.slm (1|M0)          r78      r4  null:0  0x0            0x0210001F           {$0} // wr:1+0, rd:1; fence.slm.none.group
(W)     mov (1|M0)               r79.2<1>:f    3.58732e-43:f                              
(W)     mov (2|M0)               r79.10<1>:ub  r4.11<0;1,0>:ub                  {F@1}
(W)     mov (8|M0)               null<1>:ud    r78.0<1;1,0>:ud                  {$0.dst}
(W)     send.gtwy (1|M0)         null     r79  null:0  0x0            0x02000004           {I@2,$0} // wr:1+0, rd:0; signal barrier
(W)     sync.bar                             0x0                                
        cmp (32|M0)   (eq)f1.0   null<2>:w     r1.0<1;1,0>:w     0:w              
(~f1.0) goto (32|M0)                         64                  64                
        send.slm (32|M0)         r80      r18  null:0  0x0            0x04401500           {$3} // wr:2+0, rd:4; load.slm.d32x2.a32
        add (32|M0)              r84.0<1>:f    r80.0<1;1,0>:f    r82.0<1;1,0>:f   {$3.dst}
        send.slm (32|M0)         null     r18  r84:2  0x0            0x04000504           {F@1,$5} // wr:2+2, rd:0; store.slm.d32.a32
        join (32|M0)                         16                                
(W)     send.slm (1|M0)          r86      r4  null:0  0x0            0x0210001F           {$8} // wr:1+0, rd:1; fence.slm.none.group
(W)     mov (1|M0)               r87.2<1>:f    3.58732e-43:f                              
(W)     mov (2|M0)               r87.10<1>:ub  r4.11<0;1,0>:ub                  {F@1}
(W)     mov (8|M0)               null<1>:ud    r86.0<1;1,0>:ud                  {$8.dst}
(W)     send.gtwy (1|M0)         null     r87  null:0  0x0            0x02000004           {I@2,$10} // wr:1+0, rd:0; signal barrier
(W)     sync.bar                             0x0                                
(~f1.0) goto (32|M0)                         88                  88                
(W)     mov (1|M0)               r89.0<1>:ud   0x0:uw                             
(W)     shl (1|M0)               r2.4<1>:q     r4.1<0;1,0>:ud    2:w              
(W)     send.slm (1|M0)          r88      r89  null:0  0x0            0x02108500           {I@2,$13} // wr:1+0, rd:1; load.slm.d32x1t.a32
(W)     add (1|M0)               r90.0<1>:q    r2.4<0;1,0>:q     r3.0<0;1,0>:q    {Compacted,I@1}
(W)     send.ugm (1|M0)          null     r90  r88:1  0x0            0x02008584           {I@1,$13} // wr:1+1, rd:0; store.ugm.d32x1t.a64
        join (32|M0)                         16                                
(W)     mov (16|M0)              r127.0<1>:f   r4.0<1;1,0>:f                    {Compacted}
(W)     send.gtwy (1|M0)         null     r127  null:0  0x0            0x02000010           {EOT,F@1,$15} // wr:1+0, rd:0; end of thread
(W)     mov (16|M0)              null<1>:ud    0xC98FA22F:ud                             
(W)     mov (16|M0)              null<1>:ud    0x330C2E64:ud                             
(W)     mov (16|M0)              null<1>:ud    0x0:ud                             
(W)     mov (16|M0)              null<1>:ud    0x9:ud                             
        illegal                
        illegal                
        illegal                
        illegal                
        illegal                
        illegal                
        illegal                
        illegal                
        illegal                
        illegal                
        illegal                
