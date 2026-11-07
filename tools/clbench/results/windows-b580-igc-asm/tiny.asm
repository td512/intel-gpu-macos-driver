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
(W)     mov (16|M0)              r3.0<1>:ud    r0.0<1;1,0>:ud                   {$1.dst}
(W)     or (1|M0)                cr0.0<1>:ud   cr0.0<0;1,0>:ud   0x400004C0:ud              {A@1}
(W)     mul (1|M0)               acc0.0<1>:ud  r2.3<0;1,0>:ud    r3.2<0;1,0>:uw   {A@1}
(W)     macl (1|M0)              r5.0<1>:ud    r2.3<0;1,0>:ud    r3.1<0;1,0>:ud  
(W)     mul (1|M0)               acc0.0<1>:ud  r2.3<0;1,0>:ud    r3.2<0;1,0>:uw  
(W)     mach (1|M0)              r4.0<1>:d     r2.3<0;1,0>:ud    r3.1<0;1,0>:ud  
        mov (16|M0)              r13.0<4>:uw   r1.0<1;1,0>:uw                   {$0.dst}
        mov (16|M16)             r15.0<4>:uw   r1.16<1;1,0>:uw                 
(W)     mov (1|M0)               r5.1<1>:d     r4.0<0;1,0>:d                    {I@3}
(W)     mov (1|M0)               r2.4<1>:q     -r2.0<0;1,0>:ud                 
        add (16|M0)              r17.0<1>:q    r5.0<0;1,0>:q     r13.0<4;1,0>:uw  {I@2}
        add (16|M16)             r19.0<1>:q    r5.0<0;1,0>:q     r15.0<4;1,0>:uw 
(W)     mov (2|M0)               r2.10<1>:d    r2.8<1;1,0>:d                    {I@3}
        mov (16|M0)              r6.0<1>:d     r17.0<2;1,0>:d                   {Compacted,I@3}
        mov (16|M16)             r7.0<1>:d     r19.0<2;1,0>:d                   {Compacted,I@3}
        cmp (32|M0)   (eq)f0.0   null<1>:d     r6.0<1;1,0>:d     r2.10<0;1,0>:d   {I@1}
        mov (16|M0)              r8.0<1>:d     r17.1<2;1,0>:d                   {Compacted}
        mov (16|M16)             r9.0<1>:d     r19.1<2;1,0>:d                   {Compacted}
(f0.0)  cmp (32|M0)   (eq)f0.0   null<1>:d     r8.0<1;1,0>:d     r2.11<0;1,0>:d   {I@1}
(~f0.0) goto (32|M0)                         64                  64                
(W)     mov (1|M0)               r11.0<1>:uq   r2.3<0;1,0>:uq                   {Compacted}
(W)     send.ugm (1|M0)          r10      r11  null:0  0x0            0x02108580           {I@1,$2} // wr:1+0, rd:1; load.ugm.d32x1t.a64
(W)     add (1|M0)               r12.0<1>:d    r10.0<0;1,0>:d    1:w               {Compacted,$2.dst}
(W)     send.ugm (1|M0)          null     r11  r12:1  0x0            0x02008584           {I@1,$3} // wr:1+1, rd:0; store.ugm.d32x1t.a64
        join (32|M0)                         16                                
(W)     mov (16|M0)              r127.0<1>:f   r3.0<1;1,0>:f                   
(W)     send.gtwy (1|M0)         null     r127  null:0  0x0            0x02000010           {EOT,F@1,$4} // wr:1+0, rd:0; end of thread
(W)     mov (16|M0)              null<1>:ud    0xC98FA22F:ud                             
(W)     mov (16|M0)              null<1>:ud    0x330C2E64:ud                             
(W)     mov (16|M0)              null<1>:ud    0x0:ud                             
(W)     mov (16|M0)              null<1>:ud    0x4:ud                             
        illegal                
        illegal                
        illegal                
        illegal                
        illegal                
        illegal                
        illegal                
        illegal                
        illegal                
