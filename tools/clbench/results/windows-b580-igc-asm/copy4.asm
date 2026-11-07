(W)     mov (16|M0)              r127.0<1>:ud  0x0:ud                             
(W)     and (1|M0)               r127.2<1>:ud  r0.0<0;1,0>:ud    0xFFFFFFC0:ud             
(W)     and (1|M0)               r127.0<1>:uw  r0.4<0;1,0>:uw    0xFF:uw             
(W)     add (1|M0)               r127.2<1>:ud  r127.2<0;1,0>:ud  0x20:ud              {I@2}
(W)     add (1|M0)               r127.2<1>:ud  r127.2<0;1,0>:ud  0x0:ud              {I@1}
(W)     mad (1|M0)               r127.0<1>:ud  r127.2<0;0>:ud    r127.0<0;0>:uw    0x40:uw              {I@1}
(W)     mov (8|M0)               r2.0<1>:ud    r1.0<1;1,0>:ud                  
(W)     send.ugm (1|M0)          r1       r127  null:0  0xFF000000            0x6219D500           {A@1,$0} // wr:1+0, rd:1; load.ugm.d32x16t.a32.ca.cc.bti[255]
(W)     and (1|M0)               r127.0<1>:ud  r0.0<0;1,0>:ud    0xFFFFFFC0:ud              {$0.src}
(W)     add (1|M0)               r127.0<1>:ud  r127.0<0;1,0>:ud  0x0:ud              {I@1}
(W)     send.ugm (1|M0)          r3       r127  null:0  0xFF000000            0x6219C500           {I@1,$1} // wr:1+0, rd:1; load.ugm.d32x8t.a32.ca.cc.bti[255]
(W)     mov (16|M0)              r4.0<1>:ud    r0.0<1;1,0>:ud                  
(W)     or (1|M0)                cr0.0<1>:ud   cr0.0<0;1,0>:ud   0x400004C0:ud              {A@1}
(W)     mul (1|M0)               acc0.0<1>:d   r2.3<0;1,0>:d     r4.2<0;1,0>:uw   {A@1}
(W)     macl (1|M0)              r5.0<1>:d     r2.3<0;1,0>:d     r4.1<0;1,0>:d    {Compacted}
(W)     mov (16|M0)              r127.0<1>:ud  r4.0<1;1,0>:ud                   {Compacted,$1.src}
        add3 (32|M0)             r6.0<1>:d     r5.0<0;0>:d       r1.0<1;0>:uw      r2.0<0>:d        {@2,$0.dst}
        mov (16|M0)              r24.0<2>:ud   r6.0<1;1,0>:ud                   {Compacted,I@1}
        mov (16|M16)             r26.0<2>:ud   r7.0<1;1,0>:ud                   {Compacted}
        shl (16|M0)              r29.0<1>:q    r24.0<2;1,0>:ud   4:w               {I@2}
        shl (16|M16)             r31.0<1>:q    r26.0<2;1,0>:ud   4:w               {I@2}
        add (16|M0)              r8.0<1>:q     r29.0<1;1,0>:q    r2.3<0;1,0>:q    {Compacted,I@2}
        add (16|M16)             r10.0<1>:q    r31.0<1;1,0>:q    r2.3<0;1,0>:q    {Compacted,I@2}
        send.ugm (32|M0)         r12      r8  null:0  0x0            0x08803580           {I@1,$2} // wr:4+0, rd:8; load.ugm.d32x4.a64
        add (16|M0)              r20.0<1>:q    r29.0<1;1,0>:q    r3.0<0;1,0>:q    {Compacted,$1.dst}
        add (16|M16)             r22.0<1>:q    r31.0<1;1,0>:q    r3.0<0;1,0>:q    {Compacted}
        send.ugm (32|M0)         null     r20  r12:8  0x0            0x08003584           {I@1,$2} // wr:4+8, rd:0; store.ugm.d32x4.a64
(W)     send.gtwy (1|M0)         null     r127  null:0  0x0            0x02000010           {EOT,$3} // wr:1+0, rd:0; end of thread
(W)     mov (16|M0)              null<1>:ud    0xC98FA22F:ud                             
(W)     mov (16|M0)              null<1>:ud    0x330C2E64:ud                             
(W)     mov (16|M0)              null<1>:ud    0x0:ud                             
(W)     mov (16|M0)              null<1>:ud    0x2:ud                             
        illegal                
        illegal                
        illegal                
        illegal                
        illegal                
        illegal                
        illegal                
        illegal                
