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
(W)     mov (16|M0)              r34.0<1>:ud   r0.0<1;1,0>:ud                  
(W)     or (1|M0)                cr0.0<1>:ud   cr0.0<0;1,0>:ud   0x400004C0:ud              {A@1}
(W)     mul (1|M0)               acc0.0<1>:d   r2.3<0;1,0>:d     r34.2<0;1,0>:uw  {A@1}
(W)     macl (1|M0)              r4.0<1>:d     r2.3<0;1,0>:d     r34.1<0;1,0>:d  
(W)     mov (1|M0)               r2.8<1>:d     0:w                              
        add (32|M0)              r5.0<1>:d     r4.0<0;1,0>:d     r1.0<1;1,0>:uw   {@2,$0.dst}
        add3 (32|M0)             r35.0<1>:d    r4.0<0;0>:d       r1.0<1;0>:uw      r2.0<0>:d       
        add3 (32|M0)             r7.0<1>:d     r5.0<1;0>:d       r2.0<0;0>:d       1:w               {I@2}
        add3 (32|M0)             r9.0<1>:d     r5.0<1;0>:d       r2.0<0;0>:d       2:w              
        add3 (32|M0)             r11.0<1>:d    r5.0<1;0>:d       r2.0<0;0>:d       3:w              
        add3 (32|M0)             r13.0<1>:d    r5.0<1;0>:d       r2.0<0;0>:d       4:w              
        add3 (32|M0)             r15.0<1>:d    r5.0<1;0>:d       r2.0<0;0>:d       5:w              
        add3 (32|M0)             r17.0<1>:d    r5.0<1;0>:d       r2.0<0;0>:d       6:w              
        add3 (32|M0)             r19.0<1>:d    r5.0<1;0>:d       r2.0<0;0>:d       7:w              
        mov (32|M0)              r90.0<1>:f    r35.0<1;1,0>:ud                  {I@7}
        mov (32|M0)              r92.0<1>:f    r7.0<1;1,0>:ud                   {I@7}
        mov (32|M0)              r94.0<1>:f    r9.0<1;1,0>:ud                   {I@6}
        mov (32|M0)              r96.0<1>:f    r11.0<1;1,0>:ud                  {I@5}
        mov (32|M0)              r102.0<1>:f   r13.0<1;1,0>:ud                  {I@4}
        mov (32|M0)              r104.0<1>:f   r15.0<1;1,0>:ud                  {I@3}
        mov (32|M0)              r106.0<1>:f   r17.0<1;1,0>:ud                  {I@2}
        mov (32|M0)              r108.0<1>:f   r19.0<1;1,0>:ud                  {I@1}
        mov (32|M0)              r110.0<1>:f   -r90.0<1;1,0>:f                  {Compacted,F@7}
        mov (32|M0)              r112.0<1>:f   -r92.0<1;1,0>:f                  {Compacted,F@7}
        mov (32|M0)              r114.0<1>:f   -r94.0<1;1,0>:f                  {Compacted,F@7}
        mov (32|M0)              r116.0<1>:f   -r96.0<1;1,0>:f                  {Compacted,F@7}
        mov (32|M0)              r118.0<1>:f   -r102.0<1;1,0>:f                 {Compacted,F@7}
        mov (32|M0)              r120.0<1>:f   -r104.0<1;1,0>:f                 {Compacted,F@7}
        mov (32|M0)              r122.0<1>:f   -r106.0<1;1,0>:f                 {Compacted,F@7}
        mov (32|M0)              r124.0<1>:f   -r108.0<1;1,0>:f                 {Compacted,F@7}
        mad (32|M0)              acc0.0<1>:f   r3.1<0;0>:f       r90.0<1;0>:f      r3.0<0>:f        {Compacted,$1.dst}
        mad (32|M0)              acc2.0<1>:f   r3.1<0;0>:f       r92.0<1;0>:f      r3.0<0>:f        {Compacted}
        mad (32|M0)              acc0.0<1>:f   r3.1<0;0>:f       acc0.0<1;0>:f     r3.0<0>:f        {Compacted}
        mad (32|M0)              acc2.0<1>:f   r3.1<0;0>:f       acc2.0<1;0>:f     r3.0<0>:f        {Compacted}
        mad (32|M0)              acc0.0<1>:f   r3.1<0;0>:f       acc0.0<1;0>:f     r3.0<0>:f        {Compacted}
        mad (32|M0)              acc2.0<1>:f   r3.1<0;0>:f       acc2.0<1;0>:f     r3.0<0>:f        {Compacted}
        mad (32|M0)              acc0.0<1>:f   r3.1<0;0>:f       acc0.0<1;0>:f     r3.0<0>:f        {Compacted}
        mad (32|M0)              acc2.0<1>:f   r3.1<0;0>:f       acc2.0<1;0>:f     r3.0<0>:f        {Compacted}
        mad (32|M0)              acc0.0<1>:f   r3.1<0;0>:f       acc0.0<1;0>:f     r3.0<0>:f        {Compacted}
        mad (32|M0)              acc2.0<1>:f   r3.1<0;0>:f       acc2.0<1;0>:f     r3.0<0>:f        {Compacted}
        mad (32|M0)              acc0.0<1>:f   r3.1<0;0>:f       acc0.0<1;0>:f     r3.0<0>:f        {Compacted}
        mad (32|M0)              acc2.0<1>:f   r3.1<0;0>:f       acc2.0<1;0>:f     r3.0<0>:f        {Compacted}
        mad (32|M0)              acc0.0<1>:f   r3.1<0;0>:f       acc0.0<1;0>:f     r3.0<0>:f        {Compacted}
        mad (32|M0)              acc2.0<1>:f   r3.1<0;0>:f       acc2.0<1;0>:f     r3.0<0>:f        {Compacted}
        mad (32|M0)              acc0.0<1>:f   r3.1<0;0>:f       acc0.0<1;0>:f     r3.0<0>:f        {Compacted}
        mad (32|M0)              r6.0<1>:f     r3.1<0;0>:f       r94.0<1;0>:f      r3.0<0>:f        {Compacted}
        mad (32|M0)              r8.0<1>:f     r3.1<0;0>:f       r96.0<1;0>:f      r3.0<0>:f        {Compacted}
        mad (32|M0)              r10.0<1>:f    r3.1<0;0>:f       r102.0<1;0>:f     r3.0<0>:f        {Compacted}
        mad (32|M0)              r12.0<1>:f    r3.1<0;0>:f       r104.0<1;0>:f     r3.0<0>:f        {Compacted}
        mad (32|M0)              r14.0<1>:f    r3.1<0;0>:f       r106.0<1;0>:f     r3.0<0>:f        {Compacted}
        mad (32|M0)              r16.0<1>:f    r3.1<0;0>:f       r108.0<1;0>:f     r3.0<0>:f        {Compacted}
        mad (32|M0)              r18.0<1>:f    r3.1<0;0>:f       r110.0<1;0>:f     r3.0<0>:f        {Compacted}
        mad (32|M0)              r20.0<1>:f    r3.1<0;0>:f       r112.0<1;0>:f     r3.0<0>:f        {Compacted}
        mad (32|M0)              r22.0<1>:f    r3.1<0;0>:f       r114.0<1;0>:f     r3.0<0>:f        {Compacted}
        mad (32|M0)              r24.0<1>:f    r3.1<0;0>:f       r116.0<1;0>:f     r3.0<0>:f        {Compacted}
        mad (32|M0)              r26.0<1>:f    r3.1<0;0>:f       r118.0<1;0>:f     r3.0<0>:f        {Compacted}
        mad (32|M0)              r28.0<1>:f    r3.1<0;0>:f       r120.0<1;0>:f     r3.0<0>:f        {Compacted}
        mad (32|M0)              r30.0<1>:f    r3.1<0;0>:f       r122.0<1;0>:f     r3.0<0>:f        {Compacted}
        mad (32|M0)              r32.0<1>:f    r3.1<0;0>:f       r124.0<1;0>:f     r3.0<0>:f        {Compacted}
        mad (32|M0)              acc2.0<1>:f   r3.1<0;0>:f       acc2.0<1;0>:f     r3.0<0>:f        {Compacted}
        mad (32|M0)              r38.0<1>:f    r3.1<0;0>:f       r6.0<1;0>:f       r3.0<0>:f        {Compacted}
        mad (32|M0)              r40.0<1>:f    r3.1<0;0>:f       r8.0<1;0>:f       r3.0<0>:f        {Compacted}
        mad (32|M0)              r42.0<1>:f    r3.1<0;0>:f       r10.0<1;0>:f      r3.0<0>:f        {Compacted}
        mad (32|M0)              r44.0<1>:f    r3.1<0;0>:f       r12.0<1;0>:f      r3.0<0>:f        {Compacted}
        mad (32|M0)              r46.0<1>:f    r3.1<0;0>:f       r14.0<1;0>:f      r3.0<0>:f        {Compacted}
        mad (32|M0)              r48.0<1>:f    r3.1<0;0>:f       r16.0<1;0>:f      r3.0<0>:f        {Compacted}
        mad (32|M0)              r50.0<1>:f    r3.1<0;0>:f       r18.0<1;0>:f      r3.0<0>:f        {Compacted}
        mad (32|M0)              r52.0<1>:f    r3.1<0;0>:f       r20.0<1;0>:f      r3.0<0>:f        {Compacted}
        mad (32|M0)              r54.0<1>:f    r3.1<0;0>:f       r22.0<1;0>:f      r3.0<0>:f        {Compacted}
        mad (32|M0)              r56.0<1>:f    r3.1<0;0>:f       r24.0<1;0>:f      r3.0<0>:f        {Compacted}
        mad (32|M0)              r58.0<1>:f    r3.1<0;0>:f       r26.0<1;0>:f      r3.0<0>:f        {Compacted}
        mad (32|M0)              r60.0<1>:f    r3.1<0;0>:f       r28.0<1;0>:f      r3.0<0>:f        {Compacted}
        mad (32|M0)              r62.0<1>:f    r3.1<0;0>:f       r30.0<1;0>:f      r3.0<0>:f        {Compacted}
        mad (32|M0)              r64.0<1>:f    r3.1<0;0>:f       r32.0<1;0>:f      r3.0<0>:f        {Compacted}
        mad (32|M0)              acc0.0<1>:f   r3.1<0;0>:f       acc0.0<1;0>:f     r3.0<0>:f        {Compacted}
        mad (32|M0)              r70.0<1>:f    r3.1<0;0>:f       r38.0<1;0>:f      r3.0<0>:f        {Compacted}
        mad (32|M0)              r72.0<1>:f    r3.1<0;0>:f       r40.0<1;0>:f      r3.0<0>:f        {Compacted}
        mad (32|M0)              r74.0<1>:f    r3.1<0;0>:f       r42.0<1;0>:f      r3.0<0>:f        {Compacted}
        mad (32|M0)              r76.0<1>:f    r3.1<0;0>:f       r44.0<1;0>:f      r3.0<0>:f        {Compacted}
        mad (32|M0)              r78.0<1>:f    r3.1<0;0>:f       r46.0<1;0>:f      r3.0<0>:f        {Compacted}
        mad (32|M0)              r80.0<1>:f    r3.1<0;0>:f       r48.0<1;0>:f      r3.0<0>:f        {Compacted}
        mad (32|M0)              r82.0<1>:f    r3.1<0;0>:f       r50.0<1;0>:f      r3.0<0>:f        {Compacted}
        mad (32|M0)              r84.0<1>:f    r3.1<0;0>:f       r52.0<1;0>:f      r3.0<0>:f        {Compacted}
        mad (32|M0)              r86.0<1>:f    r3.1<0;0>:f       r54.0<1;0>:f      r3.0<0>:f        {Compacted}
        mad (32|M0)              r88.0<1>:f    r3.1<0;0>:f       r56.0<1;0>:f      r3.0<0>:f        {Compacted}
        mad (32|M0)              r6.0<1>:f     r3.1<0;0>:f       r58.0<1;0>:f      r3.0<0>:f        {Compacted}
        mad (32|M0)              r8.0<1>:f     r3.1<0;0>:f       r60.0<1;0>:f      r3.0<0>:f        {Compacted}
        mad (32|M0)              r10.0<1>:f    r3.1<0;0>:f       r62.0<1;0>:f      r3.0<0>:f        {Compacted}
        mad (32|M0)              r12.0<1>:f    r3.1<0;0>:f       r64.0<1;0>:f      r3.0<0>:f        {Compacted}
        mad (32|M0)              acc2.0<1>:f   r3.1<0;0>:f       acc2.0<1;0>:f     r3.0<0>:f        {Compacted}
        mad (32|M0)              r14.0<1>:f    r3.1<0;0>:f       r70.0<1;0>:f      r3.0<0>:f        {Compacted}
        mad (32|M0)              r16.0<1>:f    r3.1<0;0>:f       r72.0<1;0>:f      r3.0<0>:f        {Compacted}
        mad (32|M0)              r18.0<1>:f    r3.1<0;0>:f       r74.0<1;0>:f      r3.0<0>:f        {Compacted}
        mad (32|M0)              r20.0<1>:f    r3.1<0;0>:f       r76.0<1;0>:f      r3.0<0>:f        {Compacted}
        mad (32|M0)              r22.0<1>:f    r3.1<0;0>:f       r78.0<1;0>:f      r3.0<0>:f        {Compacted}
        mad (32|M0)              r24.0<1>:f    r3.1<0;0>:f       r80.0<1;0>:f      r3.0<0>:f        {Compacted}
        mad (32|M0)              r26.0<1>:f    r3.1<0;0>:f       r82.0<1;0>:f      r3.0<0>:f        {Compacted}
        mad (32|M0)              r28.0<1>:f    r3.1<0;0>:f       r84.0<1;0>:f      r3.0<0>:f        {Compacted}
        mad (32|M0)              r30.0<1>:f    r3.1<0;0>:f       r86.0<1;0>:f      r3.0<0>:f        {Compacted}
        mad (32|M0)              r32.0<1>:f    r3.1<0;0>:f       r88.0<1;0>:f      r3.0<0>:f        {Compacted}
        mad (32|M0)              r38.0<1>:f    r3.1<0;0>:f       r6.0<1;0>:f       r3.0<0>:f        {Compacted}
        mad (32|M0)              r40.0<1>:f    r3.1<0;0>:f       r8.0<1;0>:f       r3.0<0>:f        {Compacted}
        mad (32|M0)              r42.0<1>:f    r3.1<0;0>:f       r10.0<1;0>:f      r3.0<0>:f        {Compacted}
        mad (32|M0)              r44.0<1>:f    r3.1<0;0>:f       r12.0<1;0>:f      r3.0<0>:f        {Compacted}
        mad (32|M0)              acc0.0<1>:f   r3.1<0;0>:f       acc0.0<1;0>:f     r3.0<0>:f        {Compacted}
        mad (32|M0)              r46.0<1>:f    r3.1<0;0>:f       r14.0<1;0>:f      r3.0<0>:f        {Compacted}
        mad (32|M0)              r48.0<1>:f    r3.1<0;0>:f       r16.0<1;0>:f      r3.0<0>:f        {Compacted}
        mad (32|M0)              r50.0<1>:f    r3.1<0;0>:f       r18.0<1;0>:f      r3.0<0>:f        {Compacted}
        mad (32|M0)              r52.0<1>:f    r3.1<0;0>:f       r20.0<1;0>:f      r3.0<0>:f        {Compacted}
        mad (32|M0)              r54.0<1>:f    r3.1<0;0>:f       r22.0<1;0>:f      r3.0<0>:f        {Compacted}
        mad (32|M0)              r56.0<1>:f    r3.1<0;0>:f       r24.0<1;0>:f      r3.0<0>:f        {Compacted}
        mad (32|M0)              r58.0<1>:f    r3.1<0;0>:f       r26.0<1;0>:f      r3.0<0>:f        {Compacted}
        mad (32|M0)              r60.0<1>:f    r3.1<0;0>:f       r28.0<1;0>:f      r3.0<0>:f        {Compacted}
        mad (32|M0)              r62.0<1>:f    r3.1<0;0>:f       r30.0<1;0>:f      r3.0<0>:f        {Compacted}
        mad (32|M0)              r64.0<1>:f    r3.1<0;0>:f       r32.0<1;0>:f      r3.0<0>:f        {Compacted}
        mad (32|M0)              r70.0<1>:f    r3.1<0;0>:f       r38.0<1;0>:f      r3.0<0>:f        {Compacted}
        mad (32|M0)              r72.0<1>:f    r3.1<0;0>:f       r40.0<1;0>:f      r3.0<0>:f        {Compacted}
        mad (32|M0)              r74.0<1>:f    r3.1<0;0>:f       r42.0<1;0>:f      r3.0<0>:f        {Compacted}
        mad (32|M0)              r76.0<1>:f    r3.1<0;0>:f       r44.0<1;0>:f      r3.0<0>:f        {Compacted}
        mad (32|M0)              acc2.0<1>:f   r3.1<0;0>:f       acc2.0<1;0>:f     r3.0<0>:f        {Compacted}
        mad (32|M0)              r78.0<1>:f    r3.1<0;0>:f       r46.0<1;0>:f      r3.0<0>:f        {Compacted}
        mad (32|M0)              r80.0<1>:f    r3.1<0;0>:f       r48.0<1;0>:f      r3.0<0>:f        {Compacted}
        mad (32|M0)              r82.0<1>:f    r3.1<0;0>:f       r50.0<1;0>:f      r3.0<0>:f        {Compacted}
        mad (32|M0)              r84.0<1>:f    r3.1<0;0>:f       r52.0<1;0>:f      r3.0<0>:f        {Compacted}
        mad (32|M0)              r86.0<1>:f    r3.1<0;0>:f       r54.0<1;0>:f      r3.0<0>:f        {Compacted}
        mad (32|M0)              r88.0<1>:f    r3.1<0;0>:f       r56.0<1;0>:f      r3.0<0>:f        {Compacted}
        mad (32|M0)              r6.0<1>:f     r3.1<0;0>:f       r58.0<1;0>:f      r3.0<0>:f        {Compacted}
        mad (32|M0)              r8.0<1>:f     r3.1<0;0>:f       r60.0<1;0>:f      r3.0<0>:f        {Compacted}
        mad (32|M0)              r10.0<1>:f    r3.1<0;0>:f       r62.0<1;0>:f      r3.0<0>:f        {Compacted}
        mad (32|M0)              r12.0<1>:f    r3.1<0;0>:f       r64.0<1;0>:f      r3.0<0>:f        {Compacted}
        mad (32|M0)              r14.0<1>:f    r3.1<0;0>:f       r70.0<1;0>:f      r3.0<0>:f        {Compacted}
        mad (32|M0)              r16.0<1>:f    r3.1<0;0>:f       r72.0<1;0>:f      r3.0<0>:f        {Compacted}
        mad (32|M0)              r18.0<1>:f    r3.1<0;0>:f       r74.0<1;0>:f      r3.0<0>:f        {Compacted}
        mad (32|M0)              r20.0<1>:f    r3.1<0;0>:f       r76.0<1;0>:f      r3.0<0>:f        {Compacted}
        mad (32|M0)              acc0.0<1>:f   r3.1<0;0>:f       acc0.0<1;0>:f     r3.0<0>:f        {Compacted}
        mad (32|M0)              r22.0<1>:f    r3.1<0;0>:f       r78.0<1;0>:f      r3.0<0>:f        {Compacted}
        mad (32|M0)              r24.0<1>:f    r3.1<0;0>:f       r80.0<1;0>:f      r3.0<0>:f        {Compacted}
        mad (32|M0)              r26.0<1>:f    r3.1<0;0>:f       r82.0<1;0>:f      r3.0<0>:f        {Compacted}
        mad (32|M0)              r28.0<1>:f    r3.1<0;0>:f       r84.0<1;0>:f      r3.0<0>:f        {Compacted}
        mad (32|M0)              r30.0<1>:f    r3.1<0;0>:f       r86.0<1;0>:f      r3.0<0>:f        {Compacted}
        mad (32|M0)              r32.0<1>:f    r3.1<0;0>:f       r88.0<1;0>:f      r3.0<0>:f        {Compacted}
        mad (32|M0)              r38.0<1>:f    r3.1<0;0>:f       r6.0<1;0>:f       r3.0<0>:f        {Compacted}
        mad (32|M0)              r40.0<1>:f    r3.1<0;0>:f       r8.0<1;0>:f       r3.0<0>:f        {Compacted}
        mad (32|M0)              r42.0<1>:f    r3.1<0;0>:f       r10.0<1;0>:f      r3.0<0>:f        {Compacted}
        mad (32|M0)              r44.0<1>:f    r3.1<0;0>:f       r12.0<1;0>:f      r3.0<0>:f        {Compacted}
        mad (32|M0)              r46.0<1>:f    r3.1<0;0>:f       r14.0<1;0>:f      r3.0<0>:f        {Compacted}
        mad (32|M0)              r48.0<1>:f    r3.1<0;0>:f       r16.0<1;0>:f      r3.0<0>:f        {Compacted}
        mad (32|M0)              r50.0<1>:f    r3.1<0;0>:f       r18.0<1;0>:f      r3.0<0>:f        {Compacted}
        mad (32|M0)              r52.0<1>:f    r3.1<0;0>:f       r20.0<1;0>:f      r3.0<0>:f        {Compacted}
        mad (32|M0)              acc2.0<1>:f   r3.1<0;0>:f       acc2.0<1;0>:f     r3.0<0>:f        {Compacted}
        mad (32|M0)              r54.0<1>:f    r3.1<0;0>:f       r22.0<1;0>:f      r3.0<0>:f        {Compacted}
        mad (32|M0)              r56.0<1>:f    r3.1<0;0>:f       r24.0<1;0>:f      r3.0<0>:f        {Compacted}
        mad (32|M0)              r58.0<1>:f    r3.1<0;0>:f       r26.0<1;0>:f      r3.0<0>:f        {Compacted}
        mad (32|M0)              r60.0<1>:f    r3.1<0;0>:f       r28.0<1;0>:f      r3.0<0>:f        {Compacted}
        mad (32|M0)              r62.0<1>:f    r3.1<0;0>:f       r30.0<1;0>:f      r3.0<0>:f        {Compacted}
        mad (32|M0)              r64.0<1>:f    r3.1<0;0>:f       r32.0<1;0>:f      r3.0<0>:f        {Compacted}
        mad (32|M0)              r70.0<1>:f    r3.1<0;0>:f       r38.0<1;0>:f      r3.0<0>:f        {Compacted}
        mad (32|M0)              r72.0<1>:f    r3.1<0;0>:f       r40.0<1;0>:f      r3.0<0>:f        {Compacted}
        mad (32|M0)              r74.0<1>:f    r3.1<0;0>:f       r42.0<1;0>:f      r3.0<0>:f        {Compacted}
        mad (32|M0)              r76.0<1>:f    r3.1<0;0>:f       r44.0<1;0>:f      r3.0<0>:f        {Compacted}
        mad (32|M0)              r78.0<1>:f    r3.1<0;0>:f       r46.0<1;0>:f      r3.0<0>:f        {Compacted}
        mad (32|M0)              r80.0<1>:f    r3.1<0;0>:f       r48.0<1;0>:f      r3.0<0>:f        {Compacted}
        mad (32|M0)              r82.0<1>:f    r3.1<0;0>:f       r50.0<1;0>:f      r3.0<0>:f        {Compacted}
        mad (32|M0)              r84.0<1>:f    r3.1<0;0>:f       r52.0<1;0>:f      r3.0<0>:f        {Compacted}
        mad (32|M0)              acc0.0<1>:f   r3.1<0;0>:f       acc0.0<1;0>:f     r3.0<0>:f        {Compacted}
        mad (32|M0)              r86.0<1>:f    r3.1<0;0>:f       r54.0<1;0>:f      r3.0<0>:f        {Compacted}
        mad (32|M0)              r88.0<1>:f    r3.1<0;0>:f       r56.0<1;0>:f      r3.0<0>:f        {Compacted}
        mad (32|M0)              r6.0<1>:f     r3.1<0;0>:f       r58.0<1;0>:f      r3.0<0>:f        {Compacted}
        mad (32|M0)              r8.0<1>:f     r3.1<0;0>:f       r60.0<1;0>:f      r3.0<0>:f        {Compacted}
        mad (32|M0)              r10.0<1>:f    r3.1<0;0>:f       r62.0<1;0>:f      r3.0<0>:f        {Compacted}
        mad (32|M0)              r12.0<1>:f    r3.1<0;0>:f       r64.0<1;0>:f      r3.0<0>:f        {Compacted}
        mad (32|M0)              r14.0<1>:f    r3.1<0;0>:f       r70.0<1;0>:f      r3.0<0>:f        {Compacted}
        mad (32|M0)              r16.0<1>:f    r3.1<0;0>:f       r72.0<1;0>:f      r3.0<0>:f        {Compacted}
        mad (32|M0)              r18.0<1>:f    r3.1<0;0>:f       r74.0<1;0>:f      r3.0<0>:f        {Compacted}
        mad (32|M0)              r20.0<1>:f    r3.1<0;0>:f       r76.0<1;0>:f      r3.0<0>:f        {Compacted}
        mad (32|M0)              r22.0<1>:f    r3.1<0;0>:f       r78.0<1;0>:f      r3.0<0>:f        {Compacted}
        mad (32|M0)              r24.0<1>:f    r3.1<0;0>:f       r80.0<1;0>:f      r3.0<0>:f        {Compacted}
        mad (32|M0)              r26.0<1>:f    r3.1<0;0>:f       r82.0<1;0>:f      r3.0<0>:f        {Compacted}
        mad (32|M0)              r28.0<1>:f    r3.1<0;0>:f       r84.0<1;0>:f      r3.0<0>:f        {Compacted}
        mad (32|M0)              acc2.0<1>:f   r3.1<0;0>:f       acc2.0<1;0>:f     r3.0<0>:f        {Compacted}
        mad (32|M0)              r30.0<1>:f    r3.1<0;0>:f       r86.0<1;0>:f      r3.0<0>:f        {Compacted}
        mad (32|M0)              r32.0<1>:f    r3.1<0;0>:f       r88.0<1;0>:f      r3.0<0>:f        {Compacted}
        mad (32|M0)              r38.0<1>:f    r3.1<0;0>:f       r6.0<1;0>:f       r3.0<0>:f        {Compacted}
        mad (32|M0)              r40.0<1>:f    r3.1<0;0>:f       r8.0<1;0>:f       r3.0<0>:f        {Compacted}
        mad (32|M0)              r42.0<1>:f    r3.1<0;0>:f       r10.0<1;0>:f      r3.0<0>:f        {Compacted}
        mad (32|M0)              r44.0<1>:f    r3.1<0;0>:f       r12.0<1;0>:f      r3.0<0>:f        {Compacted}
        mad (32|M0)              r46.0<1>:f    r3.1<0;0>:f       r14.0<1;0>:f      r3.0<0>:f        {Compacted}
        mad (32|M0)              r48.0<1>:f    r3.1<0;0>:f       r16.0<1;0>:f      r3.0<0>:f        {Compacted}
        mad (32|M0)              r50.0<1>:f    r3.1<0;0>:f       r18.0<1;0>:f      r3.0<0>:f        {Compacted}
        mad (32|M0)              r52.0<1>:f    r3.1<0;0>:f       r20.0<1;0>:f      r3.0<0>:f        {Compacted}
        mad (32|M0)              r54.0<1>:f    r3.1<0;0>:f       r22.0<1;0>:f      r3.0<0>:f        {Compacted}
        mad (32|M0)              r56.0<1>:f    r3.1<0;0>:f       r24.0<1;0>:f      r3.0<0>:f        {Compacted}
        mad (32|M0)              r58.0<1>:f    r3.1<0;0>:f       r26.0<1;0>:f      r3.0<0>:f        {Compacted}
        mad (32|M0)              r60.0<1>:f    r3.1<0;0>:f       r28.0<1;0>:f      r3.0<0>:f        {Compacted}
        mad (32|M0)              acc0.0<1>:f   r3.1<0;0>:f       acc0.0<1;0>:f     r3.0<0>:f        {Compacted}
        mad (32|M0)              r62.0<1>:f    r3.1<0;0>:f       r30.0<1;0>:f      r3.0<0>:f        {Compacted}
        mad (32|M0)              r64.0<1>:f    r3.1<0;0>:f       r32.0<1;0>:f      r3.0<0>:f        {Compacted}
        mad (32|M0)              r70.0<1>:f    r3.1<0;0>:f       r38.0<1;0>:f      r3.0<0>:f        {Compacted}
        mad (32|M0)              r72.0<1>:f    r3.1<0;0>:f       r40.0<1;0>:f      r3.0<0>:f        {Compacted}
        mad (32|M0)              r74.0<1>:f    r3.1<0;0>:f       r42.0<1;0>:f      r3.0<0>:f        {Compacted}
        mad (32|M0)              r76.0<1>:f    r3.1<0;0>:f       r44.0<1;0>:f      r3.0<0>:f        {Compacted}
        mad (32|M0)              r78.0<1>:f    r3.1<0;0>:f       r46.0<1;0>:f      r3.0<0>:f        {Compacted}
        mad (32|M0)              r80.0<1>:f    r3.1<0;0>:f       r48.0<1;0>:f      r3.0<0>:f        {Compacted}
        mad (32|M0)              r82.0<1>:f    r3.1<0;0>:f       r50.0<1;0>:f      r3.0<0>:f        {Compacted}
        mad (32|M0)              r84.0<1>:f    r3.1<0;0>:f       r52.0<1;0>:f      r3.0<0>:f        {Compacted}
        mad (32|M0)              r86.0<1>:f    r3.1<0;0>:f       r54.0<1;0>:f      r3.0<0>:f        {Compacted}
        mad (32|M0)              r88.0<1>:f    r3.1<0;0>:f       r56.0<1;0>:f      r3.0<0>:f        {Compacted}
        mad (32|M0)              r6.0<1>:f     r3.1<0;0>:f       r58.0<1;0>:f      r3.0<0>:f        {Compacted}
        mad (32|M0)              r8.0<1>:f     r3.1<0;0>:f       r60.0<1;0>:f      r3.0<0>:f        {Compacted}
        mad (32|M0)              acc2.0<1>:f   r3.1<0;0>:f       acc2.0<1;0>:f     r3.0<0>:f        {Compacted}
        mad (32|M0)              r10.0<1>:f    r3.1<0;0>:f       r62.0<1;0>:f      r3.0<0>:f        {Compacted}
        mad (32|M0)              r12.0<1>:f    r3.1<0;0>:f       r64.0<1;0>:f      r3.0<0>:f        {Compacted}
        mad (32|M0)              r14.0<1>:f    r3.1<0;0>:f       r70.0<1;0>:f      r3.0<0>:f        {Compacted}
        mad (32|M0)              r16.0<1>:f    r3.1<0;0>:f       r72.0<1;0>:f      r3.0<0>:f        {Compacted}
        mad (32|M0)              r18.0<1>:f    r3.1<0;0>:f       r74.0<1;0>:f      r3.0<0>:f        {Compacted}
        mad (32|M0)              r20.0<1>:f    r3.1<0;0>:f       r76.0<1;0>:f      r3.0<0>:f        {Compacted}
        mad (32|M0)              r22.0<1>:f    r3.1<0;0>:f       r78.0<1;0>:f      r3.0<0>:f        {Compacted}
        mad (32|M0)              r24.0<1>:f    r3.1<0;0>:f       r80.0<1;0>:f      r3.0<0>:f        {Compacted}
        mad (32|M0)              r26.0<1>:f    r3.1<0;0>:f       r82.0<1;0>:f      r3.0<0>:f        {Compacted}
        mad (32|M0)              r28.0<1>:f    r3.1<0;0>:f       r84.0<1;0>:f      r3.0<0>:f        {Compacted}
        mad (32|M0)              r30.0<1>:f    r3.1<0;0>:f       r86.0<1;0>:f      r3.0<0>:f        {Compacted}
        mad (32|M0)              r32.0<1>:f    r3.1<0;0>:f       r88.0<1;0>:f      r3.0<0>:f        {Compacted}
        mad (32|M0)              r38.0<1>:f    r3.1<0;0>:f       r6.0<1;0>:f       r3.0<0>:f        {Compacted}
        mad (32|M0)              r40.0<1>:f    r3.1<0;0>:f       r8.0<1;0>:f       r3.0<0>:f        {Compacted}
        mad (32|M0)              acc0.0<1>:f   r3.1<0;0>:f       acc0.0<1;0>:f     r3.0<0>:f        {Compacted}
        mad (32|M0)              r42.0<1>:f    r3.1<0;0>:f       r10.0<1;0>:f      r3.0<0>:f        {Compacted}
        mad (32|M0)              r44.0<1>:f    r3.1<0;0>:f       r12.0<1;0>:f      r3.0<0>:f        {Compacted}
        mad (32|M0)              r46.0<1>:f    r3.1<0;0>:f       r14.0<1;0>:f      r3.0<0>:f        {Compacted}
        mad (32|M0)              r48.0<1>:f    r3.1<0;0>:f       r16.0<1;0>:f      r3.0<0>:f        {Compacted}
        mad (32|M0)              r50.0<1>:f    r3.1<0;0>:f       r18.0<1;0>:f      r3.0<0>:f        {Compacted}
        mad (32|M0)              r52.0<1>:f    r3.1<0;0>:f       r20.0<1;0>:f      r3.0<0>:f        {Compacted}
        mad (32|M0)              r54.0<1>:f    r3.1<0;0>:f       r22.0<1;0>:f      r3.0<0>:f        {Compacted}
        mad (32|M0)              r56.0<1>:f    r3.1<0;0>:f       r24.0<1;0>:f      r3.0<0>:f        {Compacted}
        mad (32|M0)              r58.0<1>:f    r3.1<0;0>:f       r26.0<1;0>:f      r3.0<0>:f        {Compacted}
        mad (32|M0)              r60.0<1>:f    r3.1<0;0>:f       r28.0<1;0>:f      r3.0<0>:f        {Compacted}
        mad (32|M0)              r62.0<1>:f    r3.1<0;0>:f       r30.0<1;0>:f      r3.0<0>:f        {Compacted}
        mad (32|M0)              r64.0<1>:f    r3.1<0;0>:f       r32.0<1;0>:f      r3.0<0>:f        {Compacted}
        mad (32|M0)              r70.0<1>:f    r3.1<0;0>:f       r38.0<1;0>:f      r3.0<0>:f        {Compacted}
        mad (32|M0)              r72.0<1>:f    r3.1<0;0>:f       r40.0<1;0>:f      r3.0<0>:f        {Compacted}
        mad (32|M0)              acc2.0<1>:f   r3.1<0;0>:f       acc2.0<1;0>:f     r3.0<0>:f        {Compacted}
        mad (32|M0)              r74.0<1>:f    r3.1<0;0>:f       r42.0<1;0>:f      r3.0<0>:f        {Compacted}
        mad (32|M0)              r76.0<1>:f    r3.1<0;0>:f       r44.0<1;0>:f      r3.0<0>:f        {Compacted}
        mad (32|M0)              r78.0<1>:f    r3.1<0;0>:f       r46.0<1;0>:f      r3.0<0>:f        {Compacted}
        mad (32|M0)              r80.0<1>:f    r3.1<0;0>:f       r48.0<1;0>:f      r3.0<0>:f        {Compacted}
        mad (32|M0)              r82.0<1>:f    r3.1<0;0>:f       r50.0<1;0>:f      r3.0<0>:f        {Compacted}
        mad (32|M0)              r84.0<1>:f    r3.1<0;0>:f       r52.0<1;0>:f      r3.0<0>:f        {Compacted}
        mad (32|M0)              r86.0<1>:f    r3.1<0;0>:f       r54.0<1;0>:f      r3.0<0>:f        {Compacted}
        mad (32|M0)              r88.0<1>:f    r3.1<0;0>:f       r56.0<1;0>:f      r3.0<0>:f        {Compacted}
        mad (32|M0)              r6.0<1>:f     r3.1<0;0>:f       r58.0<1;0>:f      r3.0<0>:f        {Compacted}
        mad (32|M0)              r8.0<1>:f     r3.1<0;0>:f       r60.0<1;0>:f      r3.0<0>:f        {Compacted}
        mad (32|M0)              r10.0<1>:f    r3.1<0;0>:f       r62.0<1;0>:f      r3.0<0>:f        {Compacted}
        mad (32|M0)              r12.0<1>:f    r3.1<0;0>:f       r64.0<1;0>:f      r3.0<0>:f        {Compacted}
        mad (32|M0)              r14.0<1>:f    r3.1<0;0>:f       r70.0<1;0>:f      r3.0<0>:f        {Compacted}
        mad (32|M0)              r16.0<1>:f    r3.1<0;0>:f       r72.0<1;0>:f      r3.0<0>:f        {Compacted}
        mad (32|M0)              acc0.0<1>:f   r3.1<0;0>:f       acc0.0<1;0>:f     r3.0<0>:f        {Compacted}
(W)     or (1|M0)                r53.0<1>:d    r2.8<0;1,0>:d     15:w               {Compacted,F@7}
        mad (32|M0)              r19.0<1>:f    r3.1<0;0>:f       r74.0<1;0>:f      r3.0<0>:f        {Compacted}
        mad (32|M0)              r21.0<1>:f    r3.1<0;0>:f       r76.0<1;0>:f      r3.0<0>:f        {Compacted}
        mad (32|M0)              r23.0<1>:f    r3.1<0;0>:f       r78.0<1;0>:f      r3.0<0>:f        {Compacted}
        mad (32|M0)              r25.0<1>:f    r3.1<0;0>:f       r80.0<1;0>:f      r3.0<0>:f        {Compacted}
        mad (32|M0)              r27.0<1>:f    r3.1<0;0>:f       r82.0<1;0>:f      r3.0<0>:f        {Compacted}
        mad (32|M0)              r29.0<1>:f    r3.1<0;0>:f       r84.0<1;0>:f      r3.0<0>:f        {Compacted}
        mad (32|M0)              r31.0<1>:f    r3.1<0;0>:f       r86.0<1;0>:f      r3.0<0>:f        {Compacted}
        mad (32|M0)              r39.0<1>:f    r3.1<0;0>:f       r88.0<1;0>:f      r3.0<0>:f        {Compacted}
        mad (32|M0)              r41.0<1>:f    r3.1<0;0>:f       r6.0<1;0>:f       r3.0<0>:f        {Compacted}
        mad (32|M0)              r43.0<1>:f    r3.1<0;0>:f       r8.0<1;0>:f       r3.0<0>:f        {Compacted}
        mad (32|M0)              r45.0<1>:f    r3.1<0;0>:f       r10.0<1;0>:f      r3.0<0>:f        {Compacted}
        mad (32|M0)              r47.0<1>:f    r3.1<0;0>:f       r12.0<1;0>:f      r3.0<0>:f        {Compacted}
        mad (32|M0)              r49.0<1>:f    r3.1<0;0>:f       r14.0<1;0>:f      r3.0<0>:f        {Compacted}
        mad (32|M0)              r51.0<1>:f    r3.1<0;0>:f       r16.0<1;0>:f      r3.0<0>:f        {Compacted}
        mad (32|M0)              acc2.0<1>:f   r3.1<0;0>:f       acc2.0<1;0>:f     r3.0<0>:f        {Compacted}
(W)     cmp (32|M0)   (lt)f0.0   null<1>:ud    r53.0<0;1,0>:ud   0xFF:uw              {I@1}
        mad (32|M0)              r94.0<1>:f    r3.1<0;0>:f       r19.0<1;0>:f      r3.0<0>:f        {Compacted}
        mad (32|M0)              r96.0<1>:f    r3.1<0;0>:f       r21.0<1;0>:f      r3.0<0>:f        {Compacted}
        mad (32|M0)              r102.0<1>:f   r3.1<0;0>:f       r23.0<1;0>:f      r3.0<0>:f        {Compacted}
        mad (32|M0)              r104.0<1>:f   r3.1<0;0>:f       r25.0<1;0>:f      r3.0<0>:f        {Compacted}
        mad (32|M0)              r106.0<1>:f   r3.1<0;0>:f       r27.0<1;0>:f      r3.0<0>:f        {Compacted}
        mad (32|M0)              r108.0<1>:f   r3.1<0;0>:f       r29.0<1;0>:f      r3.0<0>:f        {Compacted}
        mad (32|M0)              r110.0<1>:f   r3.1<0;0>:f       r31.0<1;0>:f      r3.0<0>:f        {Compacted}
        mad (32|M0)              r112.0<1>:f   r3.1<0;0>:f       r39.0<1;0>:f      r3.0<0>:f        {Compacted}
        mad (32|M0)              r114.0<1>:f   r3.1<0;0>:f       r41.0<1;0>:f      r3.0<0>:f        {Compacted}
        mad (32|M0)              r116.0<1>:f   r3.1<0;0>:f       r43.0<1;0>:f      r3.0<0>:f        {Compacted}
        mad (32|M0)              r118.0<1>:f   r3.1<0;0>:f       r45.0<1;0>:f      r3.0<0>:f        {Compacted}
        mad (32|M0)              r120.0<1>:f   r3.1<0;0>:f       r47.0<1;0>:f      r3.0<0>:f        {Compacted}
        mad (32|M0)              r122.0<1>:f   r3.1<0;0>:f       r49.0<1;0>:f      r3.0<0>:f        {Compacted}
        mad (32|M0)              r124.0<1>:f   r3.1<0;0>:f       r51.0<1;0>:f      r3.0<0>:f        {Compacted}
        mad (32|M0)              r90.0<1>:f    r3.1<0;0>:f       acc0.0<1;0>:f     r3.0<0>:f        {Compacted}
        mad (32|M0)              r92.0<1>:f    r3.1<0;0>:f       acc2.0<1;0>:f     r3.0<0>:f       
(W&~f0.0) jmpi                               48                                
(W)     add (1|M0)               r2.8<1>:d     r2.8<0;1,0>:d     16:w              
(W)     jmpi                                 -2112                                
        add (32|M0)              acc0.0<1>:f   r90.0<1;1,0>:f    r92.0<1;1,0>:f   {Compacted,F@1}
        add (32|M0)              acc0.0<1>:f   acc0.0<1;1,0>:f   r94.0<1;1,0>:f   {Compacted}
        add (32|M0)              acc0.0<1>:f   acc0.0<1;1,0>:f   r96.0<1;1,0>:f   {Compacted}
        add (32|M0)              acc0.0<1>:f   acc0.0<1;1,0>:f   r102.0<1;1,0>:f  {Compacted}
        add (32|M0)              acc0.0<1>:f   acc0.0<1;1,0>:f   r104.0<1;1,0>:f  {Compacted}
        add (32|M0)              acc0.0<1>:f   acc0.0<1;1,0>:f   r106.0<1;1,0>:f  {Compacted}
        add (32|M0)              acc0.0<1>:f   acc0.0<1;1,0>:f   r108.0<1;1,0>:f  {Compacted}
        add (32|M0)              acc0.0<1>:f   acc0.0<1;1,0>:f   r110.0<1;1,0>:f  {Compacted}
        add (32|M0)              acc0.0<1>:f   acc0.0<1;1,0>:f   r112.0<1;1,0>:f  {Compacted}
        add (32|M0)              acc0.0<1>:f   acc0.0<1;1,0>:f   r114.0<1;1,0>:f  {Compacted}
        add (32|M0)              acc0.0<1>:f   acc0.0<1;1,0>:f   r116.0<1;1,0>:f  {Compacted}
        add (32|M0)              acc0.0<1>:f   acc0.0<1;1,0>:f   r118.0<1;1,0>:f  {Compacted}
        add (32|M0)              acc0.0<1>:f   acc0.0<1;1,0>:f   r120.0<1;1,0>:f  {Compacted}
        mov (16|M0)              r6.0<2>:ud    r35.0<1;1,0>:ud                  {Compacted}
        mov (16|M16)             r10.0<2>:ud   r36.0<1;1,0>:ud                  {Compacted}
        add (32|M0)              acc0.0<1>:f   acc0.0<1;1,0>:f   r122.0<1;1,0>:f  {Compacted}
        shl (16|M0)              r8.0<1>:q     r6.0<2;1,0>:ud    2:w               {I@2}
        shl (16|M16)             r12.0<1>:q    r10.0<2;1,0>:ud   2:w               {I@2}
        add (32|M0)              r4.0<1>:f     acc0.0<1;1,0>:f   r124.0<1;1,0>:f  {Compacted}
        add (16|M0)              r14.0<1>:q    r8.0<1;1,0>:q     r2.3<0;1,0>:q    {Compacted,I@2}
        add (16|M16)             r16.0<1>:q    r12.0<1;1,0>:q    r2.3<0;1,0>:q    {Compacted,I@2}
        send.ugm (32|M0)         null     r14  r4:2  0x0            0x08000584           {A@1,$2} // wr:4+2, rd:0; store.ugm.d32.a64
(W)     mov (16|M0)              r127.0<1>:ud  r34.0<1;1,0>:ud                  {Compacted}
(W)     send.gtwy (1|M0)         null     r127  null:0  0x0            0x02000010           {EOT,I@1,$3} // wr:1+0, rd:0; end of thread
(W)     mov (16|M0)              null<1>:ud    0xC98FA22F:ud                             
(W)     mov (16|M0)              null<1>:ud    0x330C2E64:ud                             
(W)     mov (16|M0)              null<1>:ud    0x0:ud                             
(W)     mov (16|M0)              null<1>:ud    0x1:ud                             
        illegal                
        illegal                
        illegal                
        illegal                
        illegal                
        illegal                
        illegal                
        illegal                
