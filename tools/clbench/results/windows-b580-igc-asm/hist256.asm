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
        shl (32|M0)              r5.0<1>:d     r1.0<1;1,0>:uw    2:w               {A@1,$0.dst}
        mov (32|M0)              r9.0<1>:d     0:w                              
        or (32|M0)               r7.0<1>:d     r5.0<1;1,0>:d     268435456:d               {I@2}
        send.slm (32|M0)         null     r7  r9:2  0x0            0x04000504           {I@1,$2} // wr:2+2, rd:0; store.slm.d32.a32
(W)     send.slm (1|M0)          r11      r4  null:0  0x0            0x0210001F           {$3} // wr:1+0, rd:1; fence.slm.none.group
(W)     mov (1|M0)               r12.2<1>:f    3.58732e-43:f                              
(W)     mov (2|M0)               r12.10<1>:ub  r4.11<0;1,0>:ub                  {F@1}
(W)     mov (8|M0)               null<1>:ud    r11.0<1;1,0>:ud                  {Compacted,$3.dst}
(W)     send.gtwy (1|M0)         null     r12  null:0  0x0            0x02000004           {I@2,$4} // wr:1+0, rd:0; signal barrier
(W)     sync.bar                             0x0                                
(W)     mul (1|M0)               acc0.0<1>:d   r2.3<0;1,0>:d     r4.2<0;1,0>:uw  
(W)     macl (1|M0)              r13.0<1>:d    r2.3<0;1,0>:d     r4.1<0;1,0>:d    {Compacted}
        add3 (32|M0)             r14.0<1>:d    r13.0<0;0>:d      r1.0<1;0>:uw      r2.0<0>:d        {I@1}
        cmp (32|M0)   (lt)f0.0   null<1>:d     r14.0<1;1,0>:d    r3.2<0;1,0>:d    {@1,$1.dst}
(~f0.0) goto (32|M0)                         176                  176                
        mov (16|M0)              r34.0<2>:ud   r14.0<1;1,0>:ud                  {Compacted}
        mov (16|M16)             r36.0<2>:ud   r15.0<1;1,0>:ud                  {Compacted}
        add (16|M0)              r16.0<1>:q    r2.3<0;1,0>:q     r34.0<2;1,0>:d   {I@2}
        add (16|M16)             r18.0<1>:q    r2.3<0;1,0>:q     r36.0<2;1,0>:d   {I@2}
        send.ugm (32|M0)         r20      r16  null:0  0x0            0x08200980           {I@1,$6} // wr:4+0, rd:2; load.ugm.d8u32.a64
        add (32|M0)              r14.0<1>:d    r14.0<1;1,0>:d    r3.6<0;1,0>:d   
        cmp (32|M0)   (lt)f1.0   null<1>:d     r14.0<1;1,0>:d    r3.2<0;1,0>:d    {I@1}
        shl (32|M0)              r22.0<1>:d    r20.0<1;1,0>:ud   2:w               {$6.dst}
        or (32|M0)               r24.0<1>:d    r22.0<1;1,0>:d    268435456:d               {@1,$5.src}
        send.slm (32|M0)         null     r24  null:0  0x0            0x04000508           {I@1,$5} // wr:2+0, rd:0; atomic_iinc.slm.d32.a32
(f1.0)  goto.b (32|M0)                       16                  -144                
        join (32|M0)                         16                                
(W)     send.slm (1|M0)          r26      r4  null:0  0x0            0x0210001F           {$7} // wr:1+0, rd:1; fence.slm.none.group
(W)     mov (1|M0)               r27.2<1>:f    3.58732e-43:f                              
(W)     mov (2|M0)               r27.10<1>:ub  r4.11<0;1,0>:ub                  {F@1}
(W)     mov (8|M0)               null<1>:ud    r26.0<1;1,0>:ud                  {$7.dst}
(W)     send.gtwy (1|M0)         null     r27  null:0  0x0            0x02000004           {I@2,$8} // wr:1+0, rd:0; signal barrier
(W)     sync.bar                             0x0                                
        send.slm (32|M0)         r32      r7  null:0  0x0            0x04200500           {$9} // wr:2+0, rd:2; load.slm.d32.a32
        mov (16|M0)              r38.0<4>:uw   r1.0<1;1,0>:uw                  
        mov (16|M16)             r40.0<4>:uw   r1.16<1;1,0>:uw                 
        shl (16|M0)              r42.0<1>:q    r38.0<4;1,0>:uw   2:w               {I@2}
        shl (16|M16)             r44.0<1>:q    r40.0<4;1,0>:uw   2:w               {I@2}
        add (16|M0)              r28.0<1>:q    r42.0<1;1,0>:q    r3.0<0;1,0>:q    {Compacted,I@2}
        add (16|M16)             r30.0<1>:q    r44.0<1;1,0>:q    r3.0<0;1,0>:q    {Compacted,I@2}
        send.ugm (32|M0)         null     r28  r32:2  0x0            0x0800058C           {I@1,$9} // wr:4+2, rd:0; atomic_iadd.ugm.d32.a64
(W)     mov (16|M0)              r127.0<1>:f   r4.0<1;1,0>:f                   
(W)     send.gtwy (1|M0)         null     r127  null:0  0x0            0x02000010           {EOT,F@1,$10} // wr:1+0, rd:0; end of thread
(W)     mov (16|M0)              null<1>:ud    0xC98FA22F:ud                             
(W)     mov (16|M0)              null<1>:ud    0x330C2E64:ud                             
(W)     mov (16|M0)              null<1>:ud    0x0:ud                             
(W)     mov (16|M0)              null<1>:ud    0xC:ud                             
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
