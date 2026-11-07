(W)     mov (16|M0)              r127.0<1>:ud  0x0:ud                             
(W)     and (1|M0)               r127.2<1>:ud  r0.0<0;1,0>:ud    0xFFFFFFC0:ud             
(W)     and (1|M0)               r127.0<1>:uw  r0.4<0;1,0>:uw    0xFF:uw             
(W)     add (1|M0)               r127.2<1>:ud  r127.2<0;1,0>:ud  0x20:ud              {I@2}
(W)     add (1|M0)               r127.2<1>:ud  r127.2<0;1,0>:ud  0x0:ud              {I@1}
(W)     mad (1|M0)               r127.0<1>:ud  r127.2<0;0>:ud    r127.0<0;0>:uw    0x80:uw              {I@1}
(W)     mov (8|M0)               r3.0<1>:ud    r1.0<1;1,0>:ud                  
(W)     send.ugm (1|M0)          r1       r127  null:0  0xFF000000            0x6229E500           {A@1,$0} // wr:1+0, rd:2; load.ugm.d32x32t.a32.ca.cc.bti[255]
(W)     and (1|M0)               r127.0<1>:ud  r0.0<0;1,0>:ud    0xFFFFFFC0:ud              {$0.src}
(W)     add (1|M0)               r127.0<1>:ud  r127.0<0;1,0>:ud  0x0:ud              {I@1}
(W)     send.ugm (1|M0)          r4       r127  null:0  0xFF000000            0x6219C500           {I@1,$1} // wr:1+0, rd:1; load.ugm.d32x8t.a32.ca.cc.bti[255]
(W)     mov (16|M0)              r51.0<1>:ud   r0.0<1;1,0>:ud                  
(W)     or (1|M0)                cr0.0<1>:ud   cr0.0<0;1,0>:ud   0x400004C0:ud              {A@1}
(W)     mul (1|M0)               acc0.0<1>:d   r3.4<0;1,0>:d     r51.12<0;1,0>:uw {A@1}
        mov (32|M0)              r107.0<1>:d   r2.0<1;1,0>:uw                   {$0.dst}
(W)     macl (1|M0)              r5.0<1>:d     r3.4<0;1,0>:d     r51.6<0;1,0>:d  
(W)     mul (1|M0)               acc0.0<1>:d   r3.3<0;1,0>:d     r51.2<0;1,0>:uw 
        add3 (32|M0)             r6.0<1>:d     r5.0<0;0>:d       r107.0<1;0>:d     r3.1<0>:d        {Compacted,I@2}
        mov (32|M0)              r109.0<1>:d   r1.0<1;1,0>:uw                  
(W)     macl (1|M0)              r8.0<1>:d     r3.3<0;1,0>:d     r51.1<0;1,0>:d   {Compacted}
(W)     cmp (32|M0)   (gt)f1.0   null<1>:d     r4.4<0;1,0>:d     0:w               {$1.dst}
(W)     mul (16|M0)              acc0.0<1>:d   r6.0<1;1,0>:d     r4.8<0;1,0>:uw   {I@4}
        add (32|M0)              r112.0<1>:d   r8.0<0;1,0>:d     r109.0<1;1,0>:d  {Compacted,I@3}
        macl (16|M0)             r114.0<1>:d   r6.0<1;1,0>:d     r4.4<0;1,0>:d    {Compacted}
(W)     mul (16|M16)             acc0.0<1>:d   r7.0<1;1,0>:d     r4.8<0;1,0>:uw  
        macl (16|M16)            r115.0<1>:d   r7.0<1;1,0>:d     r4.4<0;1,0>:d   
(W&f1.0) jmpi                                40                                
        mov (32|M0)              r118.0<1>:ud  0x0:ud                              {Compacted}
(W)     jmpi                                 1144                                
        shl (32|M0)              r116.0<1>:d   r107.0<1;1,0>:d   6:w               {Compacted}
        shl (32|M0)              r120.0<1>:d   r109.0<1;1,0>:d   2:w               {Compacted}
        mov (32|M0)              r118.0<1>:f   0.0:f                               {Compacted,I@4}
        add (32|M0)              r122.0<1>:d   r116.0<1;1,0>:d   r120.0<1;1,0>:d  {Compacted,I@1}
        add3 (32|M0)             r124.0<1>:d   r116.0<1;0>:d     r120.0<1;0>:d     1024:w              
(W)     mov (1|M0)               r3.8<1>:d     0:w                              
        add (32|M0)              r5.0<1>:d     r3.8<0;1,0>:d     r107.0<1;1,0>:d  {Compacted,I@1}
(W)     mul (16|M0)              acc0.0<1>:d   r5.0<1;1,0>:d     r4.8<0;1,0>:uw   {I@1}
        macl (16|M0)             r13.0<1>:d    r5.0<1;1,0>:d     r4.4<0;1,0>:d    {Compacted}
(W)     mul (16|M16)             acc0.0<1>:d   r6.0<1;1,0>:d     r4.8<0;1,0>:uw  
        macl (16|M16)            r14.0<1>:d    r6.0<1;1,0>:d     r4.4<0;1,0>:d    {Compacted}
        add3 (32|M0)             r7.0<1>:d     r114.0<1;0>:d     r3.8<0;0>:d       r109.0<1>:d     
        add3 (32|M0)             r23.0<1>:d    r13.0<1;0>:d      r112.0<1;0>:d     r3.0<0>:d        {Compacted,I@2}
        mov (16|M0)              r9.0<2>:ud    r7.0<1;1,0>:ud                   {Compacted,@2,$5.src}
        mov (16|M16)             r11.0<2>:ud   r8.0<1;1,0>:ud                   {Compacted}
        mov (16|M0)              r27.0<2>:ud   r23.0<1;1,0>:ud                  {Compacted,I@3}
        mov (16|M16)             r29.0<2>:ud   r24.0<1;1,0>:ud                 
        shl (16|M0)              r15.0<1>:q    r9.0<2;1,0>:d     2:w               {I@4}
        shl (16|M16)             r17.0<1>:q    r11.0<2;1,0>:d    2:w               {I@4}
        shl (16|M0)              r31.0<1>:q    r27.0<2;1,0>:d    2:w               {I@4}
        shl (16|M16)             r33.0<1>:q    r29.0<2;1,0>:d    2:w               {I@4}
        add (16|M0)              r19.0<1>:q    r15.0<1;1,0>:q    r3.3<0;1,0>:q    {Compacted,I@4}
        add (16|M16)             r21.0<1>:q    r17.0<1;1,0>:q    r3.3<0;1,0>:q    {Compacted,I@4}
        add (16|M0)              r35.0<1>:q    r31.0<1;1,0>:q    r4.0<0;1,0>:q    {Compacted,I@4}
        add (16|M16)             r37.0<1>:q    r33.0<1;1,0>:q    r4.0<0;1,0>:q    {Compacted,I@4}
        sync.nop                             null                             {Compacted,$3.src}
        send.ugm (32|M0)         r25      r19  null:0  0x0            0x08200580           {I@3,$6} // wr:4+0, rd:2; load.ugm.d32.a64
        sync.nop                             null                             {Compacted,$4.src}
        send.ugm (32|M0)         r39      r35  null:0  0x0            0x08200580           {I@1,$7} // wr:4+0, rd:2; load.ugm.d32.a64
        sync.nop                             null                             {$6.dst}
        send.slm (32|M0)         null     r122  r25:2  0x0            0x04000504           {$3} // wr:2+2, rd:0; store.slm.d32.a32
        sync.nop                             null                             {$7.dst}
        send.slm (32|M0)         null     r124  r39:2  0x0            0x04000504           {$4} // wr:2+2, rd:0; store.slm.d32.a32
(W)     send.slm (1|M0)          r41      r51  null:0  0x0            0x0210001F           {$8} // wr:1+0, rd:1; fence.slm.none.group
(W)     mov (1|M0)               r42.2<1>:f    3.58732e-43:f                               {$2.src}
(W)     mov (2|M0)               r42.10<1>:ub  r51.11<0;1,0>:ub                 {F@1}
(W)     mov (8|M0)               null<1>:ud    r41.0<1;1,0>:ud                  {$8.dst}
(W)     send.gtwy (1|M0)         null     r42  null:0  0x0            0x02000004           {I@2,$2} // wr:1+0, rd:0; signal barrier
(W)     sync.bar                             0x0                                
        send.slm (32|M0)         r43      r116  null:0  0x0            0x04803500           {$9} // wr:2+0, rd:8; load.slm.d32x4.a32
        send.slm (32|M0)         r52      r120  null:0  0x400000            0x04200500           {$10} // wr:2+0, rd:2; load.slm.d32.a32.flat[A+0x400]
        send.slm (32|M0)         r54      r120  null:0  0x440000            0x04200500           {$11} // wr:2+0, rd:2; load.slm.d32.a32.flat[A+0x440]
        send.slm (32|M0)         r56      r120  null:0  0x480000            0x04200500           {$12} // wr:2+0, rd:2; load.slm.d32.a32.flat[A+0x480]
        send.slm (32|M0)         r58      r120  null:0  0x4C0000            0x04200500           {$13} // wr:2+0, rd:2; load.slm.d32.a32.flat[A+0x4C0]
        send.slm (32|M0)         r60      r116  null:0  0x10000            0x04803500           {$14} // wr:2+0, rd:8; load.slm.d32x4.a32.flat[A+0x10]
        send.slm (32|M0)         r69      r120  null:0  0x500000            0x04200500           {$15} // wr:2+0, rd:2; load.slm.d32.a32.flat[A+0x500]
        send.slm (32|M0)         r71      r120  null:0  0x540000            0x04200500           {$0} // wr:2+0, rd:2; load.slm.d32.a32.flat[A+0x540]
        sync.nop                             null                             {Compacted,$10.dst}
        mad (32|M0)              acc0.0<1>:f   r118.0<1;0>:f     r52.0<1;0>:f      r43.0<1>:f       {Compacted,$9.dst}
        send.slm (32|M0)         r73      r120  null:0  0x580000            0x04200500           {$1} // wr:2+0, rd:2; load.slm.d32.a32.flat[A+0x580]
        mad (32|M0)              acc0.0<1>:f   acc0.0<1;0>:f     r54.0<1;0>:f      r45.0<1>:f       {$11.dst}
        send.slm (32|M0)         r75      r120  null:0  0x5C0000            0x04200500           {$6} // wr:2+0, rd:2; load.slm.d32.a32.flat[A+0x5C0]
        mad (32|M0)              acc0.0<1>:f   acc0.0<1;0>:f     r56.0<1;0>:f      r47.0<1>:f       {Compacted,$12.dst}
        send.slm (32|M0)         r77      r116  null:0  0x20000            0x04803500           {$7} // wr:2+0, rd:8; load.slm.d32x4.a32.flat[A+0x20]
        send.slm (32|M0)         r86      r120  null:0  0x600000            0x04200500           {$8} // wr:2+0, rd:2; load.slm.d32.a32.flat[A+0x600]
        mad (32|M0)              acc0.0<1>:f   acc0.0<1;0>:f     r58.0<1;0>:f      r49.0<1>:f       {Compacted,$13.dst}
        send.slm (32|M0)         r88      r120  null:0  0x640000            0x04200500           {$9} // wr:2+0, rd:2; load.slm.d32.a32.flat[A+0x640]
        sync.nop                             null                             {Compacted,$15.dst}
        mad (32|M0)              acc0.0<1>:f   acc0.0<1;0>:f     r69.0<1;0>:f      r60.0<1>:f       {Compacted,$14.dst}
        send.slm (32|M0)         r90      r120  null:0  0x680000            0x04200500           {$10} // wr:2+0, rd:2; load.slm.d32.a32.flat[A+0x680]
        mad (32|M0)              acc0.0<1>:f   acc0.0<1;0>:f     r71.0<1;0>:f      r62.0<1>:f       {$0.dst}
        send.slm (32|M0)         r92      r120  null:0  0x6C0000            0x04200500           {$11} // wr:2+0, rd:2; load.slm.d32.a32.flat[A+0x6C0]
        mad (32|M0)              acc0.0<1>:f   acc0.0<1;0>:f     r73.0<1;0>:f      r64.0<1>:f       {Compacted,$1.dst}
        send.slm (32|M0)         r94      r116  null:0  0x30000            0x04803500           {$12} // wr:2+0, rd:8; load.slm.d32x4.a32.flat[A+0x30]
        send.slm (32|M0)         r103     r120  null:0  0x700000            0x04200500           {$13} // wr:2+0, rd:2; load.slm.d32.a32.flat[A+0x700]
        mad (32|M0)              acc0.0<1>:f   acc0.0<1;0>:f     r75.0<1;0>:f      r66.0<1>:f       {Compacted,$6.dst}
        send.slm (32|M0)         r105     r120  null:0  0x740000            0x04200500           {$14} // wr:2+0, rd:2; load.slm.d32.a32.flat[A+0x740]
        sync.nop                             null                             {Compacted,$8.dst}
        mad (32|M0)              acc0.0<1>:f   acc0.0<1;0>:f     r86.0<1;0>:f      r77.0<1>:f       {Compacted,$7.dst}
        send.slm (32|M0)         r5       r120  null:0  0x780000            0x04200500           {$15} // wr:2+0, rd:2; load.slm.d32.a32.flat[A+0x780]
        mad (32|M0)              acc0.0<1>:f   acc0.0<1;0>:f     r88.0<1;0>:f      r79.0<1>:f       {$9.dst}
        send.slm (32|M0)         r7       r120  null:0  0x7C0000            0x04200500           {$0} // wr:2+0, rd:2; load.slm.d32.a32.flat[A+0x7C0]
        mad (32|M0)              acc0.0<1>:f   acc0.0<1;0>:f     r90.0<1;0>:f      r81.0<1>:f       {Compacted,$10.dst}
        mad (32|M0)              acc0.0<1>:f   acc0.0<1;0>:f     r92.0<1;0>:f      r83.0<1>:f       {Compacted,$11.dst}
        sync.nop                             null                             {Compacted,$13.dst}
        mad (32|M0)              acc0.0<1>:f   acc0.0<1;0>:f     r103.0<1;0>:f     r94.0<1>:f       {Compacted,$12.dst}
        mad (32|M0)              acc0.0<1>:f   acc0.0<1;0>:f     r105.0<1;0>:f     r96.0<1>:f       {Compacted,$14.dst}
        mad (32|M0)              acc0.0<1>:f   acc0.0<1;0>:f     r5.0<1;0>:f       r98.0<1>:f       {Compacted,$15.dst}
        mad (32|M0)              r118.0<1>:f   acc0.0<1;0>:f     r7.0<1;0>:f       r100.0<1>:f      {Compacted,$0.dst}
(W)     send.slm (1|M0)          r9       r51  null:0  0x0            0x0210001F           {$1} // wr:1+0, rd:1; fence.slm.none.group
(W)     mov (1|M0)               r10.2<1>:f    3.58732e-43:f                              
(W)     mov (2|M0)               r10.10<1>:ub  r51.11<0;1,0>:ub                 {F@1}
(W)     mov (8|M0)               null<1>:ud    r9.0<1;1,0>:ud                   {Compacted,$1.dst}
(W)     send.gtwy (1|M0)         null     r10  null:0  0x0            0x02000004           {I@2,$5} // wr:1+0, rd:0; signal barrier
(W)     sync.bar                             0x0                                
(W)     add (1|M0)               r3.8<1>:d     r3.8<0;1,0>:d     16:w              
(W)     cmp (32|M0)   (lt)f0.0   null<1>:d     r3.8<0;1,0>:d     r4.4<0;1,0>:d    {I@1}
(W&f0.0) jmpi                                -1048                                
        add3 (32|M0)             r5.0<1>:d     r114.0<1;0>:d     r112.0<1;0>:d     r3.0<0>:d        {Compacted}
        mov (16|M0)              r7.0<2>:ud    r5.0<1;1,0>:ud                   {Compacted,I@1}
        mov (16|M16)             r11.0<2>:ud   r6.0<1;1,0>:ud                  
        shl (16|M0)              r9.0<1>:q     r7.0<2;1,0>:d     2:w               {@2,$5.src}
        shl (16|M16)             r13.0<1>:q    r11.0<2;1,0>:d    2:w               {I@2}
        add (16|M0)              r15.0<1>:q    r9.0<1;1,0>:q     r4.1<0;1,0>:q    {Compacted,I@2}
        add (16|M16)             r17.0<1>:q    r13.0<1;1,0>:q    r4.1<0;1,0>:q    {Compacted,I@2}
        send.ugm (32|M0)         null     r15  r118:2  0x0            0x08000584           {I@1,$6} // wr:4+2, rd:0; store.ugm.d32.a64
(W)     mov (16|M0)              r127.0<1>:ud  r51.0<1;1,0>:ud                 
(W)     send.gtwy (1|M0)         null     r127  null:0  0x0            0x02000010           {EOT,I@1,$7} // wr:1+0, rd:0; end of thread
(W)     mov (16|M0)              null<1>:ud    0xC98FA22F:ud                             
(W)     mov (16|M0)              null<1>:ud    0x330C2E64:ud                             
(W)     mov (16|M0)              null<1>:ud    0x0:ud                             
(W)     mov (16|M0)              null<1>:ud    0x5:ud                             
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
