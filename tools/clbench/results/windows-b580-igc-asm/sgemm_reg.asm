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
(W)     mov (16|M0)              r42.0<1>:ud   r0.0<1;1,0>:ud                  
(W)     or (1|M0)                cr0.0<1>:ud   cr0.0<0;1,0>:ud   0x400004C0:ud              {A@1}
(W)     cmp (32|M0)   (gt)f1.0   null<1>:d     r3.6<0;1,0>:d     0:w               {A@1}
        mov (32|M0)              r74.0<1>:d    r1.0<1;1,0>:uw                   {$0.dst}
        mov (32|M0)              r108.0<1>:d   r2.0<1;1,0>:uw                  
(W)     shl (1|M0)               r3.10<1>:d    r42.6<0;1,0>:d    6:w               {I@5}
(W)     shl (1|M0)               r3.9<1>:d     r42.1<0;1,0>:d    6:w              
(W&f1.0) jmpi                                160                                
        mov (32|M0)              r68.0<1>:ud   0x0:ud                              {Compacted}
        mov (32|M0)              r66.0<1>:ud   0x0:ud                              {Compacted}
        mov (32|M0)              r64.0<1>:ud   0x0:ud                              {Compacted}
        mov (32|M0)              r62.0<1>:ud   0x0:ud                              {Compacted}
        mov (32|M0)              r38.0<1>:ud   0x0:ud                              {Compacted}
        mov (32|M0)              r30.0<1>:ud   0x0:ud                              {Compacted}
        mov (32|M0)              r26.0<1>:ud   0x0:ud                              {Compacted}
        mov (32|M0)              r28.0<1>:ud   0x0:ud                              {Compacted}
        mov (32|M0)              r32.0<1>:f    0.0:f                               {Compacted}
        mov (32|M0)              r34.0<1>:f    0.0:f                               {Compacted}
        mov (32|M0)              r60.0<1>:f    0.0:f                               {Compacted}
        mov (32|M0)              r46.0<1>:f    0.0:f                               {Compacted}
        mov (32|M0)              r48.0<1>:f    0.0:f                               {Compacted}
        mov (32|M0)              r58.0<1>:f    0.0:f                               {Compacted}
        mov (32|M0)              r56.0<1>:f    0.0:f                               {Compacted}
        mov (32|M0)              r50.0<1>:f    0.0:f                               {Compacted}
(W)     jmpi                                 4160                                
        shl (32|M0)              r20.0<1>:d    r108.0<1;1,0>:d   4:w               {Compacted}
        add (32|M0)              r6.0<1>:d     r20.0<1;1,0>:d    r74.0<1;1,0>:d   {Compacted,I@1}
        shr (32|M0)              r8.0<1>:ud    r6.0<1;1,0>:ud    4:w               {I@1}
        add (32|M0)              r4.0<1>:d     r3.10<0;1,0>:d    r8.0<1;1,0>:d    {@1,$1.dst}
        and (32|M0)              r1.0<1>:w     r1.0<1;1,0>:w     15:w              
(W)     mul (16|M0)              acc0.0<1>:d   r4.0<1;1,0>:d     r3.12<0;1,0>:uw  {I@2}
        mov (32|M0)              r72.0<1>:d    r1.0<1;1,0>:uw                   {I@2}
        macl (16|M0)             r90.0<1>:d    r4.0<1;1,0>:d     r3.6<0;1,0>:d   
(W)     mul (16|M16)             acc0.0<1>:d   r5.0<1;1,0>:d     r3.12<0;1,0>:uw 
        mul (32|M0)              r1.0<1>:w     r1.0<1;1,0>:w     272:w              
        macl (16|M16)            r91.0<1>:d    r5.0<1;1,0>:d     r3.6<0;1,0>:d    {Compacted}
        shl (32|M0)              r4.0<1>:d     r8.0<1;1,0>:d     2:w               {Compacted}
        shr (32|M0)              r88.0<1>:ud   r6.0<1;1,0>:ud    6:w              
        add3 (32|M0)             r10.0<1>:d    r20.0<1;0>:d      r74.0<1;0>:d      256:w              
        and (32|M0)              r70.0<1>:d    r6.0<1;1,0>:d     63:w               {Compacted}
        add (32|M0)              r106.0<1>:d   r4.0<1;1,0>:d     r1.0<1;1,0>:uw   {I@4}
        mul (32|M0)              r6.0<1>:d     r88.0<1;1,0>:d    272:w               {Compacted,I@4}
        shl (32|M0)              r4.0<1>:d     r70.0<1;1,0>:d    2:w               {I@3}
        shr (32|M0)              r8.0<1>:ud    r10.0<1;1,0>:ud   4:w              
        add3 (32|M0)             r104.0<1>:d   r6.0<1;0>:d       r4.0<1;0>:d       4352:w               {I@2}
        add (32|M0)              r6.0<1>:d     r3.10<0;1,0>:d    r8.0<1;1,0>:d    {Compacted,I@2}
(W)     mul (16|M0)              acc0.0<1>:d   r6.0<1;1,0>:d     r3.12<0;1,0>:uw  {I@1}
        macl (16|M0)             r86.0<1>:d    r6.0<1;1,0>:d     r3.6<0;1,0>:d    {Compacted}
(W)     mul (16|M16)             acc0.0<1>:d   r7.0<1;1,0>:d     r3.12<0;1,0>:uw 
        macl (16|M16)            r87.0<1>:d    r7.0<1;1,0>:d     r3.6<0;1,0>:d    {Compacted}
        shl (32|M0)              r6.0<1>:d     r8.0<1;1,0>:d     2:w               {Compacted}
        shr (32|M0)              r84.0<1>:ud   r10.0<1;1,0>:ud   6:w              
        add3 (32|M0)             r10.0<1>:d    r20.0<1;0>:d      r74.0<1;0>:d      512:w              
        add (32|M0)              r102.0<1>:d   r6.0<1;1,0>:d     r1.0<1;1,0>:uw   {I@3}
        mul (32|M0)              r6.0<1>:d     r84.0<1;1,0>:d    272:w               {Compacted,I@3}
        shr (32|M0)              r8.0<1>:ud    r10.0<1;1,0>:ud   4:w               {I@3}
        add3 (32|M0)             r100.0<1>:d   r6.0<1;0>:d       r4.0<1;0>:d       4352:w               {I@2}
        add (32|M0)              r6.0<1>:d     r3.10<0;1,0>:d    r8.0<1;1,0>:d    {Compacted,I@2}
(W)     mul (16|M0)              acc0.0<1>:d   r6.0<1;1,0>:d     r3.12<0;1,0>:uw  {I@1}
        macl (16|M0)             r82.0<1>:d    r6.0<1;1,0>:d     r3.6<0;1,0>:d    {Compacted}
(W)     mul (16|M16)             acc0.0<1>:d   r7.0<1;1,0>:d     r3.12<0;1,0>:uw 
        macl (16|M16)            r83.0<1>:d    r7.0<1;1,0>:d     r3.6<0;1,0>:d    {Compacted}
        shl (32|M0)              r6.0<1>:d     r8.0<1;1,0>:d     2:w              
        shr (32|M0)              r80.0<1>:ud   r10.0<1;1,0>:ud   6:w              
        add3 (32|M0)             r10.0<1>:d    r20.0<1;0>:d      r74.0<1;0>:d      768:w              
        add (32|M0)              r98.0<1>:d    r6.0<1;1,0>:d     r1.0<1;1,0>:uw   {I@3}
        mul (32|M0)              r6.0<1>:d     r80.0<1;1,0>:d    272:w               {I@3}
        shr (32|M0)              r8.0<1>:ud    r10.0<1;1,0>:ud   4:w               {I@3}
        add3 (32|M0)             r96.0<1>:d    r6.0<1;0>:d       r4.0<1;0>:d       4352:w               {I@2}
        add (32|M0)              r6.0<1>:d     r3.10<0;1,0>:d    r8.0<1;1,0>:d    {Compacted,I@2}
(W)     mul (16|M0)              acc0.0<1>:d   r6.0<1;1,0>:d     r3.12<0;1,0>:uw  {I@1}
        macl (16|M0)             r78.0<1>:d    r6.0<1;1,0>:d     r3.6<0;1,0>:d    {Compacted}
(W)     mul (16|M16)             acc0.0<1>:d   r7.0<1;1,0>:d     r3.12<0;1,0>:uw 
        macl (16|M16)            r79.0<1>:d    r7.0<1;1,0>:d     r3.6<0;1,0>:d    {Compacted}
        shl (32|M0)              r6.0<1>:d     r8.0<1;1,0>:d     2:w               {Compacted}
        shr (32|M0)              r76.0<1>:ud   r10.0<1;1,0>:ud   6:w              
        add (32|M0)              r94.0<1>:d    r6.0<1;1,0>:d     r1.0<1;1,0>:uw   {I@2}
        mul (32|M0)              r6.0<1>:d     r76.0<1;1,0>:d    272:w               {Compacted,I@2}
        shl (32|M0)              r22.0<1>:d    r74.0<1;1,0>:d    4:w               {Compacted}
        mov (32|M0)              r68.0<1>:f    0.0:f                               {Compacted}
        mov (32|M0)              r66.0<1>:f    0.0:f                               {Compacted}
        mov (32|M0)              r64.0<1>:f    0.0:f                               {Compacted}
        mov (32|M0)              r62.0<1>:f    0.0:f                               {Compacted}
        mov (32|M0)              r38.0<1>:f    0.0:f                               {Compacted}
        mov (32|M0)              r30.0<1>:f    0.0:f                               {Compacted}
        mov (32|M0)              r26.0<1>:f    0.0:f                               {Compacted}
        mov (32|M0)              r28.0<1>:f    0.0:f                               {Compacted}
        mov (32|M0)              r32.0<1>:f    0.0:f                               {Compacted}
        mov (32|M0)              r34.0<1>:f    0.0:f                               {Compacted}
        mov (32|M0)              r60.0<1>:f    0.0:f                               {Compacted}
        mov (32|M0)              r46.0<1>:f    0.0:f                               {Compacted}
        mov (32|M0)              r48.0<1>:f    0.0:f                               {Compacted}
        mov (32|M0)              r58.0<1>:f    0.0:f                               {Compacted}
        mov (32|M0)              r56.0<1>:f    0.0:f                               {Compacted}
        mov (32|M0)              r50.0<1>:f    0.0:f                               {Compacted}
        add3 (32|M0)             r92.0<1>:d    r6.0<1;0>:d       r4.0<1;0>:d       4352:w               {I@2}
(W)     mov (1|M0)               r3.8<1>:d     0:w                              
        add (32|M0)              r10.0<1>:d    r3.8<0;1,0>:d     r88.0<1;1,0>:d   {Compacted,@1,$4.src}
        add (32|M0)              r4.0<1>:d     r3.8<0;1,0>:d     r84.0<1;1,0>:d   {Compacted}
        add3 (32|M0)             r8.0<1>:d     r86.0<1;0>:d      r3.8<0;0>:d       r72.0<1>:d       {$2.src}
(W)     mul (16|M0)              acc0.0<1>:d   r10.0<1;1,0>:d    r3.12<0;1,0>:uw  {I@3}
        add3 (32|M0)             r12.0<1>:d    r90.0<1;0>:d      r3.8<0;0>:d       r72.0<1>:d       {$3.src}
        add3 (32|M0)             r6.0<1>:d     r82.0<1;0>:d      r3.8<0;0>:d       r72.0<1>:d      
        macl (16|M0)             r14.0<1>:d    r10.0<1;1,0>:d    r3.6<0;1,0>:d   
(W)     mul (16|M16)             acc0.0<1>:d   r11.0<1;1,0>:d    r3.12<0;1,0>:uw 
        macl (16|M16)            r15.0<1>:d    r11.0<1;1,0>:d    r3.6<0;1,0>:d    {Compacted}
(W)     mul (16|M0)              acc0.0<1>:d   r4.0<1;1,0>:d     r3.12<0;1,0>:uw  {I@7}
        mov (16|M0)              r24.0<2>:ud   r8.0<1;1,0>:ud                   {Compacted,I@7}
        macl (16|M0)             r8.0<1>:d     r4.0<1;1,0>:d     r3.6<0;1,0>:d   
(W)     mul (16|M16)             acc0.0<1>:d   r5.0<1;1,0>:d     r3.12<0;1,0>:uw 
        mov (16|M16)             r16.0<2>:ud   r9.0<1;1,0>:ud                   {Compacted}
        mov (16|M0)              r1.0<2>:ud    r12.0<1;1,0>:ud                  {Compacted,@7,$5.src}
        mov (16|M16)             r36.0<2>:ud   r13.0<1;1,0>:ud                  {Compacted}
        add3 (32|M0)             r10.0<1>:d    r14.0<1;0>:d      r3.9<0;0>:d       r70.0<1>:d       {I@7}
        macl (16|M16)            r9.0<1>:d     r5.0<1;1,0>:d     r3.6<0;1,0>:d    {Compacted}
        mov (16|M0)              r12.0<2>:ud   r6.0<1;1,0>:ud                   {Compacted}
        shl (16|M0)              r40.0<1>:q    r12.0<2;1,0>:d    2:w               {I@1}
        add3 (32|M0)             r12.0<1>:d    r8.0<1;0>:d       r3.9<0;0>:d       r70.0<1>:d      
        mov (16|M16)             r18.0<2>:ud   r7.0<1;1,0>:ud                   {Compacted}
        mov (16|M0)              r14.0<2>:ud   r10.0<1;1,0>:ud                 
        shl (16|M16)             r4.0<1>:q     r16.0<2;1,0>:d    2:w              
        shl (16|M0)              r6.0<1>:q     r1.0<2;1,0>:d     2:w              
        mov (16|M16)             r16.0<2>:ud   r11.0<1;1,0>:ud                 
        shl (16|M16)             r1.0<1>:q     r36.0<2;1,0>:d    2:w              
        shl (16|M0)              r43.0<1>:q    r14.0<2;1,0>:d    2:w               {I@5}
        shl (16|M0)              r36.0<1>:q    r24.0<2;1,0>:d    2:w              
        add (16|M16)             r10.0<1>:q    r1.0<1;1,0>:q     r3.0<0;1,0>:q    {Compacted,I@3}
        shl (16|M16)             r14.0<1>:q    r16.0<2;1,0>:d    2:w              
        mov (16|M0)              r1.0<2>:ud    r12.0<1;1,0>:ud                  {Compacted}
        add (16|M0)              r8.0<1>:q     r6.0<1;1,0>:q     r3.0<0;1,0>:q    {Compacted}
        shl (16|M16)             r24.0<1>:q    r18.0<2;1,0>:d    2:w              
        mov (16|M16)             r6.0<2>:ud    r13.0<1;1,0>:ud                  {Compacted}
        add (16|M0)              r16.0<1>:q    r43.0<1;1,0>:q    r3.1<0;1,0>:q    {Compacted,I@7}
        add (16|M16)             r18.0<1>:q    r14.0<1;1,0>:q    r3.1<0;1,0>:q    {Compacted,I@6}
        add (16|M0)              r12.0<1>:q    r36.0<1;1,0>:q    r3.0<0;1,0>:q   
        shl (16|M0)              r36.0<1>:q    r1.0<2;1,0>:d     2:w               {I@7}
        add (16|M16)             r14.0<1>:q    r4.0<1;1,0>:q     r3.0<0;1,0>:q    {Compacted}
        shl (16|M16)             r1.0<1>:q     r6.0<2;1,0>:d     2:w               {I@6}
        add (16|M16)             r6.0<1>:q     r24.0<1;1,0>:q    r3.0<0;1,0>:q    {Compacted}
        send.ugm (32|M0)         r24      r8  null:0  0x0            0x08200580           {I@1,$6} // wr:4+0, rd:2; load.ugm.d32.a64
        add (16|M0)              r4.0<1>:q     r40.0<1;1,0>:q    r3.0<0;1,0>:q    {Compacted}
        add (16|M0)              r8.0<1>:q     r36.0<1;1,0>:q    r3.1<0;1,0>:q    {Compacted,$6.src}
        send.ugm (32|M0)         r36      r16  null:0  0x0            0x08200580           {I@1,$7} // wr:4+0, rd:2; load.ugm.d32.a64
        send.ugm (32|M0)         r16      r12  null:0  0x0            0x08200580           {$8} // wr:4+0, rd:2; load.ugm.d32.a64
        add (16|M16)             r10.0<1>:q    r1.0<1;1,0>:q     r3.1<0;1,0>:q   
        send.ugm (32|M0)         r12      r4  null:0  0x0            0x08200580           {$9} // wr:4+0, rd:2; load.ugm.d32.a64
        send.ugm (32|M0)         r4       r8  null:0  0x0            0x08200580           {I@1,$10} // wr:4+0, rd:2; load.ugm.d32.a64
        add3 (32|M0)             r10.0<1>:d    r78.0<1;0>:d      r3.8<0;0>:d       r72.0<1>:d       {$10.src}
        add (32|M0)              r6.0<1>:d     r3.8<0;1,0>:d     r76.0<1;1,0>:d   {Compacted,$9.src}
        mov (16|M0)              r1.0<2>:ud    r10.0<1;1,0>:ud                  {Compacted,I@2}
        mov (16|M16)             r8.0<2>:ud    r11.0<1;1,0>:ud                 
        send.slm (32|M0)         null     r106  r24:2  0x0            0x04000504           {$6} // wr:2+2, rd:0; store.slm.d32.a32
        send.slm (32|M0)         null     r104  r36:2  0x0            0x04000504           {$7} // wr:2+2, rd:0; store.slm.d32.a32
        send.slm (32|M0)         null     r102  r16:2  0x0            0x04000504           {$8} // wr:2+2, rd:0; store.slm.d32.a32
        send.slm (32|M0)         null     r100  r4:2  0x0            0x04000504           {$10} // wr:2+2, rd:0; store.slm.d32.a32
        send.slm (32|M0)         null     r98  r12:2  0x0            0x04000504           {$9} // wr:2+2, rd:0; store.slm.d32.a32
        add (32|M0)              r12.0<1>:d    r3.8<0;1,0>:d     r80.0<1;1,0>:d   {Compacted,$9.src}
(W)     mul (16|M0)              acc0.0<1>:d   r12.0<1;1,0>:d    r3.12<0;1,0>:uw  {I@1}
        macl (16|M0)             r4.0<1>:d     r12.0<1;1,0>:d    r3.6<0;1,0>:d    {Compacted,$10.src}
(W)     mul (16|M16)             acc0.0<1>:d   r13.0<1;1,0>:d    r3.12<0;1,0>:uw 
        macl (16|M16)            r5.0<1>:d     r13.0<1;1,0>:d    r3.6<0;1,0>:d   
(W)     mul (16|M0)              acc0.0<1>:d   r6.0<1;1,0>:d     r3.12<0;1,0>:uw 
        shl (16|M0)              r12.0<1>:q    r1.0<2;1,0>:d     2:w              
        add3 (32|M0)             r10.0<1>:d    r4.0<1;0>:d       r3.9<0;0>:d       r70.0<1>:d       {I@3}
        shl (16|M16)             r1.0<1>:q     r8.0<2;1,0>:d     2:w              
        macl (16|M0)             r8.0<1>:d     r6.0<1;1,0>:d     r3.6<0;1,0>:d    {Compacted}
(W)     mul (16|M16)             acc0.0<1>:d   r7.0<1;1,0>:d     r3.12<0;1,0>:uw 
        macl (16|M16)            r9.0<1>:d     r7.0<1;1,0>:d     r3.6<0;1,0>:d    {Compacted}
        add (16|M0)              r4.0<1>:q     r12.0<1;1,0>:q    r3.0<0;1,0>:q    {Compacted,I@6}
        add (16|M16)             r6.0<1>:q     r1.0<1;1,0>:q     r3.0<0;1,0>:q    {Compacted,I@5}
        mov (16|M0)              r12.0<2>:ud   r10.0<1;1,0>:ud                  {Compacted}
        mov (16|M16)             r1.0<2>:ud    r11.0<1;1,0>:ud                  {Compacted}
        add3 (32|M0)             r10.0<1>:d    r8.0<1;0>:d       r3.9<0;0>:d       r70.0<1>:d       {I@5}
        shl (16|M0)              r14.0<1>:q    r12.0<2;1,0>:d    2:w               {I@3}
        shl (16|M16)             r12.0<1>:q    r1.0<2;1,0>:d     2:w               {I@3}
        send.ugm (32|M0)         r8       r4  null:0  0x0            0x08200580           {I@3,$11} // wr:4+0, rd:2; load.ugm.d32.a64
        mov (16|M0)              r16.0<2>:ud   r10.0<1;1,0>:ud                  {Compacted,$8.src}
        mov (16|M16)             r1.0<2>:ud    r11.0<1;1,0>:ud                  {Compacted}
        add (16|M0)              r4.0<1>:q     r14.0<1;1,0>:q    r3.1<0;1,0>:q    {Compacted,@4,$11.src}
        add (16|M16)             r6.0<1>:q     r12.0<1;1,0>:q    r3.1<0;1,0>:q    {Compacted,I@4}
        shl (16|M16)             r14.0<1>:q    r1.0<2;1,0>:d     2:w               {I@3}
        shl (16|M0)              r12.0<1>:q    r16.0<2;1,0>:d    2:w              
        send.ugm (32|M0)         r10      r4  null:0  0x0            0x08200580           {I@3,$12} // wr:4+0, rd:2; load.ugm.d32.a64
        add (16|M0)              r4.0<1>:q     r12.0<1;1,0>:q    r3.1<0;1,0>:q    {Compacted,@1,$12.src}
        add (16|M16)             r6.0<1>:q     r14.0<1;1,0>:q    r3.1<0;1,0>:q    {Compacted}
        send.ugm (32|M0)         r12      r4  null:0  0x0            0x08200580           {I@1,$13} // wr:4+0, rd:2; load.ugm.d32.a64
        sync.nop                             null                             {Compacted,$12.dst}
        send.slm (32|M0)         null     r96  r10:2  0x0            0x04000504           {$4} // wr:2+2, rd:0; store.slm.d32.a32
        sync.nop                             null                             {Compacted,$11.dst}
        send.slm (32|M0)         null     r94  r8:2  0x0            0x04000504           {$2} // wr:2+2, rd:0; store.slm.d32.a32
        sync.nop                             null                             {Compacted,$13.dst}
        send.slm (32|M0)         null     r92  r12:2  0x0            0x04000504           {$3} // wr:2+2, rd:0; store.slm.d32.a32
(W)     send.slm (1|M0)          r1       r42  null:0  0x0            0x0210001F           {$14} // wr:1+0, rd:1; fence.slm.none.group
(W)     mov (8|M0)               null<1>:ud    r1.0<1;1,0>:ud                   {Compacted,$14.dst}
(W)     mov (1|M0)               r1.2<1>:f     3.58732e-43:f                               {I@1}
(W)     mov (2|M0)               r1.10<1>:ub   r42.11<0;1,0>:ub                 {F@1}
(W)     send.gtwy (1|M0)         null     r1  null:0  0x0            0x02000004           {I@1,$15} // wr:1+0, rd:0; signal barrier
(W)     sync.bar                             0x0                                
(W)     mov (1|M0)               r3.7<1>:d     0:w                              
(W)     mul (1|M0)               r2.0<1>:d     r3.7<0;1,0>:d     272:w               {I@1}
(W)     or (1|M0)                r2.1<1>:d     r3.7<0;1,0>:d     1:w              
        add (32|M0)              r4.0<1>:d     r2.0<0;1,0>:d     r20.0<1;1,0>:d   {I@2}
        add3 (32|M0)             r24.0<1>:d    r2.0<0;0>:d       r22.0<1;0>:d      4352:w               {$6.src}
        send.slm (32|M0)         r12      r4  null:0  0x0            0x04803500           {I@2,$0} // wr:2+0, rd:8; load.slm.d32x4.a32
        send.slm (32|M0)         r4       r24  null:0  0x0            0x04803500           {I@1,$6} // wr:2+0, rd:8; load.slm.d32x4.a32
(W)     mul (1|M0)               r2.0<1>:d     r2.1<0;1,0>:d     272:w               {Compacted}
(W)     or (1|M0)                r2.1<1>:d     r3.7<0;1,0>:d     2:w              
        sync.nop                             null                             {Compacted,$6.dst}
        mad (32|M0)              acc0.0<1>:f   r50.0<1;0>:f      r4.0<1;0>:f       r12.0<1>:f       {Compacted,$0.dst}
        mad (32|M0)              r44.0<1>:f    r32.0<1;0>:f      r10.0<1;0>:f      r14.0<1>:f       {Compacted}
        mad (32|M0)              acc2.0<1>:f   r56.0<1;0>:f      r6.0<1;0>:f       r12.0<1>:f       {Compacted}
        mad (32|M0)              r24.0<1>:f    r48.0<1;0>:f      r10.0<1;0>:f      r12.0<1>:f       {Compacted}
        mad (32|M0)              r50.0<1>:f    r28.0<1;0>:f      r4.0<1;0>:f       r16.0<1>:f       {Compacted}
        mad (32|M0)              r32.0<1>:f    r62.0<1;0>:f      r4.0<1;0>:f       r18.0<1>:f       {Compacted}
        mad (32|M0)              r56.0<1>:f    r46.0<1;0>:f      r4.0<1;0>:f       r14.0<1>:f       {Compacted}
        mad (32|M0)              r40.0<1>:f    r34.0<1;0>:f      r8.0<1;0>:f       r14.0<1>:f       {Compacted}
        mad (32|M0)              r48.0<1>:f    r26.0<1;0>:f      r6.0<1;0>:f       r16.0<1>:f       {Compacted}
        add (32|M0)              r4.0<1>:d     r2.0<0;1,0>:d     r20.0<1;1,0>:d   {Compacted,A@2}
        mad (32|M0)              r46.0<1>:f    r30.0<1;0>:f      r8.0<1;0>:f       r16.0<1>:f       {Compacted}
        mad (32|M0)              r34.0<1>:f    r38.0<1;0>:f      r10.0<1;0>:f      r16.0<1>:f       {Compacted}
        add3 (32|M0)             r26.0<1>:d    r2.0<0;0>:d       r22.0<1;0>:d      4352:w               {F@3}
        mad (32|M0)              r36.0<1>:f    r58.0<1;0>:f      r8.0<1;0>:f       r12.0<1>:f       {Compacted,$7.src}
        mad (32|M0)              r52.0<1>:f    r60.0<1;0>:f      r6.0<1;0>:f       r14.0<1>:f       {Compacted}
        mad (32|M0)              r54.0<1>:f    r66.0<1;0>:f      r8.0<1;0>:f       r18.0<1>:f       {Compacted}
        mad (32|M0)              r30.0<1>:f    r64.0<1;0>:f      r6.0<1;0>:f       r18.0<1>:f       {Compacted}
        mad (32|M0)              r38.0<1>:f    r68.0<1;0>:f      r10.0<1;0>:f      r18.0<1>:f       {Compacted}
        send.slm (32|M0)         r12      r4  null:0  0x0            0x04803500           {A@1,$8} // wr:2+0, rd:8; load.slm.d32x4.a32
        send.slm (32|M0)         r4       r26  null:0  0x0            0x04803500           {I@1,$9} // wr:2+0, rd:8; load.slm.d32x4.a32
(W)     mul (1|M0)               r2.0<1>:d     r2.1<0;1,0>:d     272:w               {Compacted}
(W)     or (1|M0)                r2.1<1>:d     r3.7<0;1,0>:d     3:w              
        sync.nop                             null                             {Compacted,$9.dst}
        mad (32|M0)              r28.0<1>:f    r36.0<1;0>:f      r8.0<1;0>:f       r12.0<1>:f       {Compacted,$8.dst}
        mad (32|M0)              r36.0<1>:f    r52.0<1;0>:f      r6.0<1;0>:f       r14.0<1>:f       {Compacted}
        mad (32|M0)              r52.0<1>:f    r40.0<1;0>:f      r8.0<1;0>:f       r14.0<1>:f       {Compacted}
        mad (32|M0)              r40.0<1>:f    r44.0<1;0>:f      r10.0<1;0>:f      r14.0<1>:f       {Compacted}
        mad (32|M0)              r44.0<1>:f    r50.0<1;0>:f      r4.0<1;0>:f       r16.0<1>:f       {Compacted}
        mad (32|M0)              r50.0<1>:f    r48.0<1;0>:f      r6.0<1;0>:f       r16.0<1>:f       {Compacted}
        mad (32|M0)              r48.0<1>:f    r46.0<1;0>:f      r8.0<1;0>:f       r16.0<1>:f       {Compacted}
        mad (32|M0)              r26.0<1>:f    r24.0<1;0>:f      r10.0<1;0>:f      r12.0<1>:f       {Compacted}
        mad (32|M0)              r46.0<1>:f    r34.0<1;0>:f      r10.0<1;0>:f      r16.0<1>:f       {Compacted}
        mad (32|M0)              acc0.0<1>:f   acc0.0<1;0>:f     r4.0<1;0>:f       r12.0<1>:f       {Compacted}
        mad (32|M0)              r24.0<1>:f    r56.0<1;0>:f      r4.0<1;0>:f       r14.0<1>:f       {Compacted}
        mad (32|M0)              r34.0<1>:f    r32.0<1;0>:f      r4.0<1;0>:f       r18.0<1>:f       {Compacted}
        mad (32|M0)              r56.0<1>:f    r38.0<1;0>:f      r10.0<1;0>:f      r18.0<1>:f       {Compacted}
        add (32|M0)              r4.0<1>:d     r2.0<0;1,0>:d     r20.0<1;1,0>:d   {Compacted,A@2}
        mad (32|M0)              r32.0<1>:f    r30.0<1;0>:f      r6.0<1;0>:f       r18.0<1>:f       {Compacted}
        add3 (32|M0)             r38.0<1>:d    r2.0<0;0>:d       r22.0<1;0>:d      4352:w               {F@2}
        mad (32|M0)              acc2.0<1>:f   acc2.0<1;0>:f     r6.0<1;0>:f       r12.0<1>:f       {Compacted}
        mad (32|M0)              r30.0<1>:f    r54.0<1;0>:f      r8.0<1;0>:f       r18.0<1>:f       {Compacted}
        send.slm (32|M0)         r12      r4  null:0  0x0            0x04803500           {A@1,$10} // wr:2+0, rd:8; load.slm.d32x4.a32
        send.slm (32|M0)         r4       r38  null:0  0x0            0x04803500           {I@1,$11} // wr:2+0, rd:8; load.slm.d32x4.a32
(W)     mul (1|M0)               r2.0<1>:d     r2.1<0;1,0>:d     272:w               {Compacted}
(W)     or (1|M0)                r2.1<1>:d     r3.7<0;1,0>:d     4:w              
        sync.nop                             null                             {Compacted,$11.dst}
        mad (32|M0)              r38.0<1>:f    r28.0<1;0>:f      r8.0<1;0>:f       r12.0<1>:f       {Compacted,$10.dst}
        mad (32|M0)              r28.0<1>:f    r26.0<1;0>:f      r10.0<1;0>:f      r12.0<1>:f       {Compacted}
        mad (32|M0)              r26.0<1>:f    r24.0<1;0>:f      r4.0<1;0>:f       r14.0<1>:f       {Compacted}
        mad (32|M0)              r24.0<1>:f    r36.0<1;0>:f      r6.0<1;0>:f       r14.0<1>:f       {Compacted}
        mad (32|M0)              r54.0<1>:f    r40.0<1;0>:f      r10.0<1;0>:f      r14.0<1>:f       {Compacted}
        mad (32|M0)              r36.0<1>:f    r52.0<1;0>:f      r8.0<1;0>:f       r14.0<1>:f       {Compacted}
        mad (32|M0)              r40.0<1>:f    r44.0<1;0>:f      r4.0<1;0>:f       r16.0<1>:f       {Compacted}
        mad (32|M0)              r52.0<1>:f    r48.0<1;0>:f      r8.0<1;0>:f       r16.0<1>:f       {Compacted}
        mad (32|M0)              acc0.0<1>:f   acc0.0<1;0>:f     r4.0<1;0>:f       r12.0<1>:f       {Compacted}
        mad (32|M0)              r44.0<1>:f    r50.0<1;0>:f      r6.0<1;0>:f       r16.0<1>:f       {Compacted}
        mad (32|M0)              r48.0<1>:f    r34.0<1;0>:f      r4.0<1;0>:f       r18.0<1>:f       {Compacted}
        mad (32|M0)              r50.0<1>:f    r46.0<1;0>:f      r10.0<1;0>:f      r16.0<1>:f       {Compacted}
        mad (32|M0)              r34.0<1>:f    r30.0<1;0>:f      r8.0<1;0>:f       r18.0<1>:f       {Compacted}
        add (32|M0)              r4.0<1>:d     r2.0<0;1,0>:d     r20.0<1;1,0>:d   {Compacted,A@2}
        mad (32|M0)              r46.0<1>:f    r32.0<1;0>:f      r6.0<1;0>:f       r18.0<1>:f       {Compacted}
        add3 (32|M0)             r30.0<1>:d    r2.0<0;0>:d       r22.0<1;0>:d      4352:w               {F@2}
        mad (32|M0)              acc2.0<1>:f   acc2.0<1;0>:f     r6.0<1;0>:f       r12.0<1>:f       {Compacted}
        mad (32|M0)              r32.0<1>:f    r56.0<1;0>:f      r10.0<1;0>:f      r18.0<1>:f       {Compacted}
        send.slm (32|M0)         r12      r4  null:0  0x0            0x04803500           {A@1,$12} // wr:2+0, rd:8; load.slm.d32x4.a32
        send.slm (32|M0)         r4       r30  null:0  0x0            0x04803500           {I@1,$13} // wr:2+0, rd:8; load.slm.d32x4.a32
(W)     mul (1|M0)               r2.0<1>:d     r2.1<0;1,0>:d     272:w               {Compacted}
(W)     or (1|M0)                r2.1<1>:d     r3.7<0;1,0>:d     5:w              
        sync.nop                             null                             {Compacted,$13.dst}
        mad (32|M0)              r30.0<1>:f    r38.0<1;0>:f      r8.0<1;0>:f       r12.0<1>:f       {Compacted,$12.dst}
        mad (32|M0)              r38.0<1>:f    r28.0<1;0>:f      r10.0<1;0>:f      r12.0<1>:f       {Compacted}
        mad (32|M0)              r28.0<1>:f    r26.0<1;0>:f      r4.0<1;0>:f       r14.0<1>:f       {Compacted}
        mad (32|M0)              r26.0<1>:f    r24.0<1;0>:f      r6.0<1;0>:f       r14.0<1>:f       {Compacted}
        mad (32|M0)              r56.0<1>:f    r40.0<1;0>:f      r4.0<1;0>:f       r16.0<1>:f       {Compacted}
        mad (32|M0)              r24.0<1>:f    r36.0<1;0>:f      r8.0<1;0>:f       r14.0<1>:f       {Compacted}
        mad (32|M0)              r40.0<1>:f    r44.0<1;0>:f      r6.0<1;0>:f       r16.0<1>:f       {Compacted}
        mad (32|M0)              r36.0<1>:f    r54.0<1;0>:f      r10.0<1;0>:f      r14.0<1>:f       {Compacted}
        mad (32|M0)              r44.0<1>:f    r52.0<1;0>:f      r8.0<1;0>:f       r16.0<1>:f       {Compacted}
        mad (32|M0)              r54.0<1>:f    r50.0<1;0>:f      r10.0<1;0>:f      r16.0<1>:f       {Compacted}
        mad (32|M0)              acc0.0<1>:f   acc0.0<1;0>:f     r4.0<1;0>:f       r12.0<1>:f       {Compacted}
        mad (32|M0)              r52.0<1>:f    r48.0<1;0>:f      r4.0<1;0>:f       r18.0<1>:f       {Compacted}
        mad (32|M0)              r50.0<1>:f    r46.0<1;0>:f      r6.0<1;0>:f       r18.0<1>:f       {Compacted}
        add (32|M0)              r4.0<1>:d     r2.0<0;1,0>:d     r20.0<1;1,0>:d   {Compacted,A@2}
        mad (32|M0)              r46.0<1>:f    r32.0<1;0>:f      r10.0<1;0>:f      r18.0<1>:f       {Compacted}
        add3 (32|M0)             r32.0<1>:d    r2.0<0;0>:d       r22.0<1;0>:d      4352:w               {F@1}
        mad (32|M0)              acc2.0<1>:f   acc2.0<1;0>:f     r6.0<1;0>:f       r12.0<1>:f       {Compacted}
        mad (32|M0)              r48.0<1>:f    r34.0<1;0>:f      r8.0<1;0>:f       r18.0<1>:f       {Compacted}
        send.slm (32|M0)         r12      r4  null:0  0x0            0x04803500           {A@1,$14} // wr:2+0, rd:8; load.slm.d32x4.a32
        send.slm (32|M0)         r4       r32  null:0  0x0            0x04803500           {I@1,$0} // wr:2+0, rd:8; load.slm.d32x4.a32
(W)     mul (1|M0)               r2.0<1>:d     r2.1<0;1,0>:d     272:w               {Compacted}
(W)     or (1|M0)                r2.1<1>:d     r3.7<0;1,0>:d     6:w              
        sync.nop                             null                             {Compacted,$0.dst}
        mad (32|M0)              r34.0<1>:f    r30.0<1;0>:f      r8.0<1;0>:f       r12.0<1>:f       {Compacted,$14.dst}
        mad (32|M0)              r30.0<1>:f    r28.0<1;0>:f      r4.0<1;0>:f       r14.0<1>:f       {Compacted}
        mad (32|M0)              r28.0<1>:f    r26.0<1;0>:f      r6.0<1;0>:f       r14.0<1>:f       {Compacted}
        mad (32|M0)              r26.0<1>:f    r24.0<1;0>:f      r8.0<1;0>:f       r14.0<1>:f       {Compacted}
        mad (32|M0)              r24.0<1>:f    r36.0<1;0>:f      r10.0<1;0>:f      r14.0<1>:f       {Compacted}
        mad (32|M0)              r36.0<1>:f    r40.0<1;0>:f      r6.0<1;0>:f       r16.0<1>:f       {Compacted}
        mad (32|M0)              r40.0<1>:f    r44.0<1;0>:f      r8.0<1;0>:f       r16.0<1>:f       {Compacted}
        mad (32|M0)              r44.0<1>:f    r54.0<1;0>:f      r10.0<1;0>:f      r16.0<1>:f       {Compacted}
        mad (32|M0)              r54.0<1>:f    r52.0<1;0>:f      r4.0<1;0>:f       r18.0<1>:f       {Compacted}
        mad (32|M0)              r32.0<1>:f    r38.0<1;0>:f      r10.0<1;0>:f      r12.0<1>:f       {Compacted}
        mad (32|M0)              r52.0<1>:f    r50.0<1;0>:f      r6.0<1;0>:f       r18.0<1>:f       {Compacted}
        mad (32|M0)              acc0.0<1>:f   acc0.0<1;0>:f     r4.0<1;0>:f       r12.0<1>:f       {Compacted}
        mad (32|M0)              r38.0<1>:f    r56.0<1;0>:f      r4.0<1;0>:f       r16.0<1>:f       {Compacted}
        mad (32|M0)              r50.0<1>:f    r48.0<1;0>:f      r8.0<1;0>:f       r18.0<1>:f       {Compacted}
        add (32|M0)              r4.0<1>:d     r2.0<0;1,0>:d     r20.0<1;1,0>:d   {Compacted,A@2}
        mad (32|M0)              r48.0<1>:f    r46.0<1;0>:f      r10.0<1;0>:f      r18.0<1>:f       {Compacted}
        add3 (32|M0)             r46.0<1>:d    r2.0<0;0>:d       r22.0<1;0>:d      4352:w               {F@1}
        mad (32|M0)              acc2.0<1>:f   acc2.0<1;0>:f     r6.0<1;0>:f       r12.0<1>:f      
        send.slm (32|M0)         r12      r4  null:0  0x0            0x04803500           {A@1,$6} // wr:2+0, rd:8; load.slm.d32x4.a32
        send.slm (32|M0)         r4       r46  null:0  0x0            0x04803500           {I@1,$7} // wr:2+0, rd:8; load.slm.d32x4.a32
(W)     mul (1|M0)               r2.0<1>:d     r2.1<0;1,0>:d     272:w              
(W)     or (1|M0)                r2.1<1>:d     r3.7<0;1,0>:d     7:w              
(W)     cmp (32|M0)   (lt)f2.0   null<1>:ud    r2.1<0;1,0>:ud    0xF:uw              {I@1}
        sync.nop                             null                             {Compacted,$7.dst}
        mad (32|M0)              r46.0<1>:f    r34.0<1;0>:f      r8.0<1;0>:f       r12.0<1>:f       {Compacted,$6.dst}
        mad (32|M0)              r34.0<1>:f    r32.0<1;0>:f      r10.0<1;0>:f      r12.0<1>:f       {Compacted}
        mad (32|M0)              r32.0<1>:f    r30.0<1;0>:f      r4.0<1;0>:f       r14.0<1>:f       {Compacted}
        mad (32|M0)              r30.0<1>:f    r28.0<1;0>:f      r6.0<1;0>:f       r14.0<1>:f       {Compacted}
        mad (32|M0)              r28.0<1>:f    r26.0<1;0>:f      r8.0<1;0>:f       r14.0<1>:f       {Compacted}
        mad (32|M0)              r26.0<1>:f    r24.0<1;0>:f      r10.0<1;0>:f      r14.0<1>:f       {Compacted}
        mad (32|M0)              r24.0<1>:f    r38.0<1;0>:f      r4.0<1;0>:f       r16.0<1>:f       {Compacted}
        mad (32|M0)              r38.0<1>:f    r36.0<1;0>:f      r6.0<1;0>:f       r16.0<1>:f       {Compacted}
        mad (32|M0)              r36.0<1>:f    r40.0<1;0>:f      r8.0<1;0>:f       r16.0<1>:f       {Compacted}
        mad (32|M0)              r40.0<1>:f    r44.0<1;0>:f      r10.0<1;0>:f      r16.0<1>:f       {Compacted}
        mad (32|M0)              r44.0<1>:f    r54.0<1;0>:f      r4.0<1;0>:f       r18.0<1>:f       {Compacted}
        mad (32|M0)              r54.0<1>:f    r52.0<1;0>:f      r6.0<1;0>:f       r18.0<1>:f       {Compacted}
        mad (32|M0)              acc0.0<1>:f   acc0.0<1;0>:f     r4.0<1;0>:f       r12.0<1>:f       {Compacted}
        mad (32|M0)              r52.0<1>:f    r50.0<1;0>:f      r8.0<1;0>:f       r18.0<1>:f       {Compacted}
        add (32|M0)              r4.0<1>:d     r2.0<0;1,0>:d     r20.0<1;1,0>:d   {Compacted,F@2}
        mad (32|M0)              r50.0<1>:f    r48.0<1;0>:f      r10.0<1;0>:f      r18.0<1>:f       {Compacted}
        add3 (32|M0)             r48.0<1>:d    r2.0<0;0>:d       r22.0<1;0>:d      4352:w               {F@1}
        mad (32|M0)              acc2.0<1>:f   acc2.0<1;0>:f     r6.0<1;0>:f       r12.0<1>:f       {Compacted}
        send.slm (32|M0)         r12      r4  null:0  0x0            0x04803500           {A@1,$8} // wr:2+0, rd:8; load.slm.d32x4.a32
        send.slm (32|M0)         r4       r48  null:0  0x0            0x04803500           {I@1,$9} // wr:2+0, rd:8; load.slm.d32x4.a32
(W)     mul (1|M0)               r2.0<1>:d     r2.1<0;1,0>:d     272:w               {Compacted}
        sync.nop                             null                             {Compacted,$9.dst}
        mad (32|M0)              r48.0<1>:f    r46.0<1;0>:f      r8.0<1;0>:f       r12.0<1>:f       {Compacted,$8.dst}
        mad (32|M0)              r46.0<1>:f    r34.0<1;0>:f      r10.0<1;0>:f      r12.0<1>:f       {Compacted}
        mad (32|M0)              r34.0<1>:f    r32.0<1;0>:f      r4.0<1;0>:f       r14.0<1>:f       {Compacted}
        mad (32|M0)              r32.0<1>:f    r30.0<1;0>:f      r6.0<1;0>:f       r14.0<1>:f       {Compacted}
        mad (32|M0)              r30.0<1>:f    r28.0<1;0>:f      r8.0<1;0>:f       r14.0<1>:f       {Compacted}
        mad (32|M0)              r28.0<1>:f    r26.0<1;0>:f      r10.0<1;0>:f      r14.0<1>:f       {Compacted}
        mad (32|M0)              r26.0<1>:f    r24.0<1;0>:f      r4.0<1;0>:f       r16.0<1>:f       {Compacted}
        mad (32|M0)              r24.0<1>:f    r38.0<1;0>:f      r6.0<1;0>:f       r16.0<1>:f       {Compacted}
        mad (32|M0)              r38.0<1>:f    r36.0<1;0>:f      r8.0<1;0>:f       r16.0<1>:f       {Compacted}
        mad (32|M0)              r36.0<1>:f    r40.0<1;0>:f      r10.0<1;0>:f      r16.0<1>:f       {Compacted}
        mad (32|M0)              r40.0<1>:f    r44.0<1;0>:f      r4.0<1;0>:f       r18.0<1>:f       {Compacted}
        mad (32|M0)              r44.0<1>:f    r54.0<1;0>:f      r6.0<1;0>:f       r18.0<1>:f       {Compacted}
        mad (32|M0)              acc0.0<1>:f   acc0.0<1;0>:f     r4.0<1;0>:f       r12.0<1>:f       {Compacted}
        mad (32|M0)              r54.0<1>:f    r52.0<1;0>:f      r8.0<1;0>:f       r18.0<1>:f       {Compacted}
        add (32|M0)              r4.0<1>:d     r2.0<0;1,0>:d     r20.0<1;1,0>:d   {Compacted,A@1}
        mad (32|M0)              r52.0<1>:f    r50.0<1;0>:f      r10.0<1;0>:f      r18.0<1>:f       {Compacted}
        add3 (32|M0)             r50.0<1>:d    r2.0<0;0>:d       r22.0<1;0>:d      4352:w               {F@1}
        mad (32|M0)              acc2.0<1>:f   acc2.0<1;0>:f     r6.0<1;0>:f       r12.0<1>:f      
        send.slm (32|M0)         r12      r4  null:0  0x0            0x04803500           {A@1,$10} // wr:2+0, rd:8; load.slm.d32x4.a32
        send.slm (32|M0)         r4       r50  null:0  0x0            0x04803500           {I@1,$11} // wr:2+0, rd:8; load.slm.d32x4.a32
        sync.nop                             null                             {Compacted,$11.dst}
        mad (32|M0)              r58.0<1>:f    r48.0<1;0>:f      r8.0<1;0>:f       r12.0<1>:f       {Compacted,$10.dst}
        mad (32|M0)              r48.0<1>:f    r46.0<1;0>:f      r10.0<1;0>:f      r12.0<1>:f       {Compacted}
        mad (32|M0)              r60.0<1>:f    r32.0<1;0>:f      r6.0<1;0>:f       r14.0<1>:f       {Compacted}
        mad (32|M0)              r46.0<1>:f    r34.0<1;0>:f      r4.0<1;0>:f       r14.0<1>:f       {Compacted}
        mad (32|M0)              r32.0<1>:f    r28.0<1;0>:f      r10.0<1;0>:f      r14.0<1>:f       {Compacted}
        mad (32|M0)              r34.0<1>:f    r30.0<1;0>:f      r8.0<1;0>:f       r14.0<1>:f       {Compacted}
        mad (32|M0)              r28.0<1>:f    r26.0<1;0>:f      r4.0<1;0>:f       r16.0<1>:f       {Compacted}
        mad (32|M0)              r30.0<1>:f    r38.0<1;0>:f      r8.0<1;0>:f       r16.0<1>:f       {Compacted}
        mad (32|M0)              r50.0<1>:f    acc0.0<1;0>:f     r4.0<1;0>:f       r12.0<1>:f       {Compacted}
        mad (32|M0)              r56.0<1>:f    acc2.0<1;0>:f     r6.0<1;0>:f       r12.0<1>:f       {Compacted}
        mad (32|M0)              r62.0<1>:f    r40.0<1;0>:f      r4.0<1;0>:f       r18.0<1>:f       {Compacted}
        mad (32|M0)              r64.0<1>:f    r44.0<1;0>:f      r6.0<1;0>:f       r18.0<1>:f       {Compacted}
        mad (32|M0)              r66.0<1>:f    r54.0<1;0>:f      r8.0<1;0>:f       r18.0<1>:f       {Compacted}
        mad (32|M0)              r68.0<1>:f    r52.0<1;0>:f      r10.0<1;0>:f      r18.0<1>:f       {Compacted}
        mad (32|M0)              r26.0<1>:f    r24.0<1;0>:f      r6.0<1;0>:f       r16.0<1>:f       {Compacted}
        mad (32|M0)              r38.0<1>:f    r36.0<1;0>:f      r10.0<1;0>:f      r16.0<1>:f      
(W&~f2.0) jmpi                               48                                
(W)     add (1|M0)               r3.7<1>:d     r3.7<0;1,0>:d     8:w              
(W)     jmpi                                 -1808                                
        sync.nop                             null                             {Compacted,$15.src}
(W)     send.slm (1|M0)          r1       r42  null:0  0x0            0x0210001F           {$12} // wr:1+0, rd:1; fence.slm.none.group
(W)     mov (8|M0)               null<1>:ud    r1.0<1;1,0>:ud                   {Compacted,$12.dst}
(W)     mov (1|M0)               r1.2<1>:f     3.58732e-43:f                               {I@1}
(W)     mov (2|M0)               r1.10<1>:ub   r42.11<0;1,0>:ub                 {F@1}
(W)     send.gtwy (1|M0)         null     r1  null:0  0x0            0x02000004           {I@1,$5} // wr:1+0, rd:0; signal barrier
(W)     sync.bar                             0x0                                
(W)     add (1|M0)               r3.8<1>:d     r3.8<0;1,0>:d     16:w              
(W)     cmp (32|M0)   (lt)f0.0   null<1>:d     r3.8<0;1,0>:d     r3.6<0;1,0>:d    {I@1}
(W&f0.0) jmpi                                -3264                                
        shl (32|M0)              r6.0<1>:d     r108.0<1;1,0>:d   2:w               {Compacted}
        add (32|M0)              r4.0<1>:d     r3.10<0;1,0>:d    r6.0<1;1,0>:d    {Compacted,@1,$1.dst}
(W)     mul (16|M0)              acc0.0<1>:d   r4.0<1;1,0>:d     r3.12<0;1,0>:uw  {I@1}
        shl (32|M0)              r8.0<1>:d     r74.0<1;1,0>:d    2:w               {Compacted,$2.src}
        macl (16|M0)             r6.0<1>:d     r4.0<1;1,0>:d     r3.6<0;1,0>:d    {Compacted}
(W)     mul (16|M16)             acc0.0<1>:d   r5.0<1;1,0>:d     r3.12<0;1,0>:uw 
        macl (16|M16)            r7.0<1>:d     r5.0<1;1,0>:d     r3.6<0;1,0>:d   
        add3 (32|M0)             r4.0<1>:d     r6.0<1;0>:d       r3.9<0;0>:d       r8.0<1>:d        {I@1}
        mov (16|M0)              r1.0<2>:ud    r4.0<1;1,0>:ud                   {Compacted,@1,$5.src}
        shl (16|M0)              r6.0<1>:q     r1.0<2;1,0>:d     2:w               {I@1}
        mov (16|M16)             r1.0<2>:ud    r5.0<1;1,0>:ud                   {Compacted}
        shl (16|M16)             r4.0<1>:q     r1.0<2;1,0>:d     2:w               {I@1}
        mov (32|M0)              r10.0<1>:ud   r48.0<1;1,0>:ud                  {Compacted,$4.src}
        mov (32|M0)              r8.0<1>:ud    r58.0<1;1,0>:ud                  {Compacted}
        add (16|M0)              r12.0<1>:q    r6.0<1;1,0>:q     r3.2<0;1,0>:q    {Compacted,$3.src}
        add (16|M16)             r14.0<1>:q    r4.0<1;1,0>:q     r3.2<0;1,0>:q    {Compacted,I@4}
        mov (32|M0)              r6.0<1>:ud    r56.0<1;1,0>:ud                  {Compacted}
        mov (32|M0)              r4.0<1>:ud    r50.0<1;1,0>:ud                  {Compacted}
(W)     shl (1|M0)               r1.0<1>:q     r3.6<0;1,0>:d     2:w              
        send.ugm (32|M0)         null     r12  r4:8  0x0            0x08003584           {I@2,$13} // wr:4+8, rd:0; store.ugm.d32x4.a64
        mov (32|M0)              r2.0<1>:ud    r46.0<1;1,0>:ud                  {Compacted}
        add (16|M0)              r16.0<1>:q    r12.0<1;1,0>:q    r1.0<0;1,0>:q    {Compacted,I@2}
        add (16|M16)             r18.0<1>:q    r14.0<1;1,0>:q    r1.0<0;1,0>:q    {Compacted}
        mov (32|M0)              r4.0<1>:ud    r60.0<1;1,0>:ud                  {Compacted,$13.src}
        mov (32|M0)              r6.0<1>:ud    r34.0<1;1,0>:ud                  {Compacted}
        mov (32|M0)              r8.0<1>:ud    r32.0<1;1,0>:ud                  {Compacted}
        send.ugm (32|M0)         null     r16  r2:8  0x0            0x08003584           {I@1,$14} // wr:4+8, rd:0; store.ugm.d32x4.a64
        add (16|M0)              r10.0<1>:q    r16.0<1;1,0>:q    r1.0<0;1,0>:q    {Compacted}
        add (16|M16)             r12.0<1>:q    r18.0<1;1,0>:q    r1.0<0;1,0>:q    {Compacted}
        mov (32|M0)              r2.0<1>:f     r28.0<1;1,0>:f                   {Compacted,$14.src}
        mov (32|M0)              r4.0<1>:f     r26.0<1;1,0>:f                   {Compacted}
        mov (32|M0)              r6.0<1>:f     r30.0<1;1,0>:f                   {Compacted}
        mov (32|M0)              r8.0<1>:f     r38.0<1;1,0>:f                   {Compacted}
        send.ugm (32|M0)         null     r10  r2:8  0x0            0x08003584           {A@1,$15} // wr:4+8, rd:0; store.ugm.d32x4.a64
        add (16|M0)              r14.0<1>:q    r10.0<1;1,0>:q    r1.0<0;1,0>:q    {Compacted}
        add (16|M16)             r16.0<1>:q    r12.0<1;1,0>:q    r1.0<0;1,0>:q    {Compacted}
        mov (32|M0)              r2.0<1>:f     r62.0<1;1,0>:f                   {Compacted,$15.src}
        mov (32|M0)              r4.0<1>:f     r64.0<1;1,0>:f                   {Compacted}
        mov (32|M0)              r6.0<1>:f     r66.0<1;1,0>:f                   {Compacted}
        mov (32|M0)              r8.0<1>:f     r68.0<1;1,0>:f                   {Compacted}
        send.ugm (32|M0)         null     r14  r2:8  0x0            0x08003584           {A@1,$0} // wr:4+8, rd:0; store.ugm.d32x4.a64
(W)     mov (16|M0)              r112.0<1>:ud  r42.0<1;1,0>:ud                 
(W)     send.gtwy (1|M0)         null     r112  null:0  0x0            0x02000010           {EOT,I@1,$1} // wr:1+0, rd:0; end of thread
(W)     mov (16|M0)              null<1>:ud    0xC98FA22F:ud                             
(W)     mov (16|M0)              null<1>:ud    0x330C2E64:ud                             
(W)     mov (16|M0)              null<1>:ud    0x0:ud                             
(W)     mov (16|M0)              null<1>:ud    0x6:ud                             
        illegal                
        illegal                
        illegal                
        illegal                
        illegal                
        illegal                
        illegal                
        illegal                
        illegal                
