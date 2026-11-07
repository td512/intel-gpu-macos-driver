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
(W)     mov (16|M0)              r7.0<1>:ud    r0.0<1;1,0>:ud                  
(W)     or (1|M0)                cr0.0<1>:ud   cr0.0<0;1,0>:ud   0x400004C0:ud              {A@1}
(W)     mul (1|M0)               acc0.0<1>:d   r3.3<0;1,0>:d     r7.2<0;1,0>:uw   {A@1}
(W)     macl (1|M0)              r5.0<1>:d     r3.3<0;1,0>:d     r7.1<0;1,0>:d   
        add3 (32|M0)             r121.0<1>:d   r5.0<0;0>:d       r1.0<1;0>:uw      r3.0<0>:d        {@1,$0.dst}
        cmp (32|M0)   (lt)f0.0   null<1>:d     r121.0<1;1,0>:d   r4.2<0;1,0>:d    {@1,$1.dst}
(~f0.0) goto (32|M0)                         1968                  1968                
(W)     mul (1|M0)               acc0.0<1>:d   r3.4<0;1,0>:d     r7.12<0;1,0>:uw 
(W)     macl (1|M0)              r9.0<1>:d     r3.4<0;1,0>:d     r7.6<0;1,0>:d    {Compacted}
(W)     add (1|M0)               r1.0<1>:d     r4.3<0;1,0>:d     -1:w               {Compacted}
        add3 (32|M0)             r13.0<1>:d    r9.0<0;0>:d       r2.0<1;0>:uw      r3.1<0>:d        {I@2}
        sel (32|M0)   (ge)f0.0   r15.0<1>:d    r13.0<1;1,0>:d    4:w               {I@1}
        sel (32|M0)   (ge)f0.0   r17.0<1>:d    r13.0<1;1,0>:d    3:w              
        add (32|M0)              r21.0<1>:d    r15.0<1;1,0>:d    -4:w               {I@2}
        sel (32|M0)   (ge)f0.0   r19.0<1>:d    r13.0<1;1,0>:d    2:w              
        add (32|M0)              r23.0<1>:d    r17.0<1;1,0>:d    -3:w               {Compacted,I@3}
        sel (32|M0)   (lt)f0.0   r29.0<1>:d    r1.0<0;1,0>:d     r21.0<1;1,0>:d   {I@3}
        sel (32|M0)   (ge)f0.0   r27.0<1>:d    r13.0<1;1,0>:d    1:w              
        add (32|M0)              r25.0<1>:d    r19.0<1;1,0>:d    -2:w               {Compacted,I@4}
        sel (32|M0)   (lt)f0.0   r31.0<1>:d    r1.0<0;1,0>:d     r23.0<1;1,0>:d   {I@4}
(W)     mul (16|M0)              acc0.0<1>:d   r29.0<1;1,0>:d    r4.4<0;1,0>:uw   {I@4}
        add (32|M0)              r35.0<1>:d    r27.0<1;1,0>:d    -1:w               {Compacted,I@4}
        macl (16|M0)             r39.0<1>:d    r29.0<1;1,0>:d    r4.2<0;1,0>:d    {Compacted}
(W)     mul (16|M16)             acc0.0<1>:d   r30.0<1;1,0>:d    r4.4<0;1,0>:uw  
        sel (32|M0)   (lt)f0.0   r33.0<1>:d    r1.0<0;1,0>:d     r25.0<1;1,0>:d   {I@6}
        macl (16|M16)            r40.0<1>:d    r30.0<1;1,0>:d    r4.2<0;1,0>:d    {Compacted}
(W)     mul (16|M0)              acc0.0<1>:d   r31.0<1;1,0>:d    r4.4<0;1,0>:uw   {I@7}
        sel (32|M0)   (ge)f0.0   r41.0<1>:d    r13.0<1;1,0>:d    -1:w              
        macl (16|M0)             r49.0<1>:d    r31.0<1;1,0>:d    r4.2<0;1,0>:d    {Compacted}
(W)     mul (16|M16)             acc0.0<1>:d   r32.0<1;1,0>:d    r4.4<0;1,0>:uw  
        sel (32|M0)   (ge)f0.0   r37.0<1>:d    r13.0<1;1,0>:d    0:w              
        sel (32|M0)   (lt)f0.0   r43.0<1>:d    r1.0<0;1,0>:d     r35.0<1;1,0>:d   {I@7}
        add (32|M0)              r53.0<1>:d    r39.0<1;1,0>:d    r121.0<1;1,0>:d  {Compacted,I@7}
        macl (16|M16)            r50.0<1>:d    r32.0<1;1,0>:d    r4.2<0;1,0>:d    {Compacted}
(W)     mul (16|M0)              acc0.0<1>:d   r33.0<1;1,0>:d    r4.4<0;1,0>:uw  
        sel (32|M0)   (ge)f0.0   r51.0<1>:d    r13.0<1;1,0>:d    -2:w              
        add (32|M0)              r47.0<1>:d    r41.0<1;1,0>:d    1:w               {Compacted,I@7}
        macl (16|M0)             r59.0<1>:d    r33.0<1;1,0>:d    r4.2<0;1,0>:d    {Compacted}
(W)     mul (16|M16)             acc0.0<1>:d   r34.0<1;1,0>:d    r4.4<0;1,0>:uw  
        sel (32|M0)   (lt)f0.0   r45.0<1>:d    r1.0<0;1,0>:d     r37.0<1;1,0>:d   {I@7}
        add (32|M0)              r63.0<1>:d    r49.0<1;1,0>:d    r121.0<1;1,0>:d  {Compacted,I@7}
        macl (16|M16)            r60.0<1>:d    r34.0<1;1,0>:d    r4.2<0;1,0>:d    {Compacted}
(W)     mul (16|M0)              acc0.0<1>:d   r43.0<1;1,0>:d    r4.4<0;1,0>:uw  
        sel (32|M0)   (ge)f0.0   r61.0<1>:d    r13.0<1;1,0>:d    -3:w              
        mov (16|M0)              r65.0<2>:ud   r53.0<1;1,0>:ud                  {Compacted}
        mov (16|M16)             r67.0<2>:ud   r54.0<1;1,0>:ud                  {Compacted}
        add (32|M0)              r57.0<1>:d    r51.0<1;1,0>:d    2:w               {Compacted,I@7}
        macl (16|M0)             r71.0<1>:d    r43.0<1;1,0>:d    r4.2<0;1,0>:d    {Compacted}
(W)     mul (16|M16)             acc0.0<1>:d   r44.0<1;1,0>:d    r4.4<0;1,0>:uw  
        sel (32|M0)   (lt)f0.0   r55.0<1>:d    r1.0<0;1,0>:d     r47.0<1;1,0>:d  
        add (32|M0)              r75.0<1>:d    r59.0<1;1,0>:d    r121.0<1;1,0>:d  {Compacted,I@7}
        macl (16|M16)            r72.0<1>:d    r44.0<1;1,0>:d    r4.2<0;1,0>:d    {Compacted}
(W)     mul (16|M0)              acc0.0<1>:d   r45.0<1;1,0>:d    r4.4<0;1,0>:uw  
        sel (32|M0)   (ge)f0.0   r77.0<1>:d    r13.0<1;1,0>:d    -4:w              
        mov (16|M0)              r85.0<2>:ud   r63.0<1;1,0>:ud                  {Compacted}
        mov (16|M16)             r87.0<2>:ud   r64.0<1;1,0>:ud                  {Compacted}
        add (32|M0)              r73.0<1>:d    r61.0<1;1,0>:d    3:w               {Compacted}
        shl (16|M0)              r79.0<1>:q    r65.0<2;1,0>:d    2:w              
        shl (16|M16)             r83.0<1>:q    r67.0<2;1,0>:d    2:w              
        macl (16|M0)             r81.0<1>:d    r45.0<1;1,0>:d    r4.2<0;1,0>:d    {Compacted}
(W)     mul (16|M16)             acc0.0<1>:d   r46.0<1;1,0>:d    r4.4<0;1,0>:uw  
        sel (32|M0)   (lt)f0.0   r69.0<1>:d    r1.0<0;1,0>:d     r57.0<1;1,0>:d  
        add (32|M0)              r89.0<1>:d    r71.0<1;1,0>:d    r121.0<1;1,0>:d  {Compacted,I@7}
        macl (16|M16)            r82.0<1>:d    r46.0<1;1,0>:d    r4.2<0;1,0>:d    {Compacted}
(W)     mul (16|M0)              acc0.0<1>:d   r55.0<1;1,0>:d    r4.4<0;1,0>:uw  
        mov (16|M0)              r101.0<2>:ud  r75.0<1;1,0>:ud                  {Compacted}
        mov (16|M16)             r103.0<2>:ud  r76.0<1;1,0>:ud                  {Compacted}
        add (32|M0)              r95.0<1>:d    r77.0<1;1,0>:d    4:w               {Compacted}
        shl (16|M0)              r97.0<1>:q    r85.0<2;1,0>:d    2:w              
        shl (16|M16)             r99.0<1>:q    r87.0<2;1,0>:d    2:w              
        add (16|M0)              r105.0<1>:q   r79.0<1;1,0>:q    r3.3<0;1,0>:q    {Compacted}
        add (16|M16)             r107.0<1>:q   r83.0<1;1,0>:q    r3.3<0;1,0>:q    {Compacted}
        macl (16|M0)             r93.0<1>:d    r55.0<1;1,0>:d    r4.2<0;1,0>:d    {Compacted}
(W)     mul (16|M16)             acc0.0<1>:d   r56.0<1;1,0>:d    r4.4<0;1,0>:uw  
        sel (32|M0)   (lt)f0.0   r91.0<1>:d    r1.0<0;1,0>:d     r73.0<1;1,0>:d  
        add (32|M0)              r111.0<1>:d   r81.0<1;1,0>:d    r121.0<1;1,0>:d  {Compacted}
        macl (16|M16)            r94.0<1>:d    r56.0<1;1,0>:d    r4.2<0;1,0>:d    {Compacted}
(W)     mul (16|M0)              acc0.0<1>:d   r69.0<1;1,0>:d    r4.4<0;1,0>:uw  
        send.ugm (32|M0)         r19      r105  null:0  0x0            0x08200580           {I@7,$2} // wr:4+0, rd:2; load.ugm.d32.a64
        mov (16|M0)              r117.0<2>:ud  r89.0<1;1,0>:ud                  {Compacted}
        mov (16|M16)             r119.0<2>:ud  r90.0<1;1,0>:ud                  {Compacted}
        shl (16|M0)              r113.0<1>:q   r101.0<2;1,0>:d   2:w              
        shl (16|M16)             r115.0<1>:q   r103.0<2;1,0>:d   2:w              
        add (16|M0)              r15.0<1>:q    r97.0<1;1,0>:q    r3.3<0;1,0>:q    {Compacted}
        add (16|M16)             r17.0<1>:q    r99.0<1;1,0>:q    r3.3<0;1,0>:q    {Compacted}
        macl (16|M0)             r109.0<1>:d   r69.0<1;1,0>:d    r4.2<0;1,0>:d    {Compacted}
(W)     mul (16|M16)             acc0.0<1>:d   r70.0<1;1,0>:d    r4.4<0;1,0>:uw  
        sel (32|M0)   (lt)f0.0   r21.0<1>:d    r1.0<0;1,0>:d     r95.0<1;1,0>:d  
        add (32|M0)              r25.0<1>:d    r93.0<1;1,0>:d    r121.0<1;1,0>:d  {Compacted,I@7}
        macl (16|M16)            r110.0<1>:d   r70.0<1;1,0>:d    r4.2<0;1,0>:d    {Compacted}
(W)     mul (16|M0)              acc0.0<1>:d   r91.0<1;1,0>:d    r4.4<0;1,0>:uw  
        send.ugm (32|M0)         r41      r15  null:0  0x0            0x08200580           {I@7,$3} // wr:4+0, rd:2; load.ugm.d32.a64
        mov (16|M0)              r31.0<2>:ud   r111.0<1;1,0>:ud                 {Compacted}
        mov (16|M16)             r33.0<2>:ud   r112.0<1;1,0>:ud                
        shl (16|M0)              r27.0<1>:q    r117.0<2;1,0>:d   2:w              
        shl (16|M16)             r29.0<1>:q    r119.0<2;1,0>:d   2:w              
        add (16|M0)              r35.0<1>:q    r113.0<1;1,0>:q   r3.3<0;1,0>:q    {Compacted}
        add (16|M16)             r37.0<1>:q    r115.0<1;1,0>:q   r3.3<0;1,0>:q    {Compacted}
        macl (16|M0)             r23.0<1>:d    r91.0<1;1,0>:d    r4.2<0;1,0>:d   
(W)     mul (16|M16)             acc0.0<1>:d   r92.0<1;1,0>:d    r4.4<0;1,0>:uw  
        add (32|M0)              r43.0<1>:d    r109.0<1;1,0>:d   r121.0<1;1,0>:d  {Compacted,I@7}
        macl (16|M16)            r24.0<1>:d    r92.0<1;1,0>:d    r4.2<0;1,0>:d    {Compacted}
(W)     mul (16|M0)              acc0.0<1>:d   r21.0<1;1,0>:d    r4.4<0;1,0>:uw  
        send.ugm (32|M0)         r59      r35  null:0  0x0            0x08200580           {I@6,$4} // wr:4+0, rd:2; load.ugm.d32.a64
        mov (16|M0)              r51.0<2>:ud   r25.0<1;1,0>:ud                  {Compacted}
        mov (16|M16)             r53.0<2>:ud   r26.0<1;1,0>:ud                  {Compacted}
        shl (16|M0)              r45.0<1>:q    r31.0<2;1,0>:d    2:w              
        shl (16|M16)             r49.0<1>:q    r33.0<2;1,0>:d    2:w              
        add (16|M0)              r55.0<1>:q    r27.0<1;1,0>:q    r3.3<0;1,0>:q    {Compacted}
        add (16|M16)             r57.0<1>:q    r29.0<1;1,0>:q    r3.3<0;1,0>:q    {Compacted}
        macl (16|M0)             r47.0<1>:d    r21.0<1;1,0>:d    r4.2<0;1,0>:d    {Compacted}
(W)     mul (16|M16)             acc0.0<1>:d   r22.0<1;1,0>:d    r4.4<0;1,0>:uw  
        add (32|M0)              r61.0<1>:d    r23.0<1;1,0>:d    r121.0<1;1,0>:d  {Compacted,I@7}
        macl (16|M16)            r48.0<1>:d    r22.0<1;1,0>:d    r4.2<0;1,0>:d    {Compacted}
        send.ugm (32|M0)         r77      r55  null:0  0x0            0x08200580           {I@5,$5} // wr:4+0, rd:2; load.ugm.d32.a64
        mov (16|M0)              r67.0<2>:ud   r43.0<1;1,0>:ud                  {Compacted}
        mov (16|M16)             r69.0<2>:ud   r44.0<1;1,0>:ud                  {Compacted}
        shl (16|M0)              r63.0<1>:q    r51.0<2;1,0>:d    2:w              
        shl (16|M16)             r65.0<1>:q    r53.0<2;1,0>:d    2:w              
        add (16|M0)              r71.0<1>:q    r45.0<1;1,0>:q    r3.3<0;1,0>:q    {Compacted}
        add (16|M16)             r73.0<1>:q    r49.0<1;1,0>:q    r3.3<0;1,0>:q    {Compacted}
        add (32|M0)              r79.0<1>:d    r47.0<1;1,0>:d    r121.0<1;1,0>:d  {Compacted,I@7}
        send.ugm (32|M0)         r93      r71  null:0  0x0            0x08200580           {I@2,$6} // wr:4+0, rd:2; load.ugm.d32.a64
        mov (16|M0)              r85.0<2>:ud   r61.0<1;1,0>:ud                  {Compacted}
        mov (16|M16)             r87.0<2>:ud   r62.0<1;1,0>:ud                  {Compacted}
        shl (16|M0)              r81.0<1>:q    r67.0<2;1,0>:d    2:w              
        shl (16|M16)             r83.0<1>:q    r69.0<2;1,0>:d    2:w              
        add (16|M0)              r89.0<1>:q    r63.0<1;1,0>:q    r3.3<0;1,0>:q    {Compacted}
        add (16|M16)             r91.0<1>:q    r65.0<1;1,0>:q    r3.3<0;1,0>:q    {Compacted}
        send.ugm (32|M0)         r109     r89  null:0  0x0            0x08200580           {I@1,$7} // wr:4+0, rd:2; load.ugm.d32.a64
        mov (16|M0)              r99.0<2>:ud   r79.0<1;1,0>:ud                  {Compacted}
        mov (16|M16)             r101.0<2>:ud  r80.0<1;1,0>:ud                  {Compacted}
        shl (16|M0)              r95.0<1>:q    r85.0<2;1,0>:d    2:w              
        shl (16|M16)             r97.0<1>:q    r87.0<2;1,0>:d    2:w              
        add (16|M0)              r103.0<1>:q   r81.0<1;1,0>:q    r3.3<0;1,0>:q    {Compacted}
        add (16|M16)             r105.0<1>:q   r83.0<1;1,0>:q    r3.3<0;1,0>:q    {Compacted,$2.src}
        send.ugm (32|M0)         r119     r103  null:0  0x0            0x08200580           {I@1,$8} // wr:4+0, rd:2; load.ugm.d32.a64
        shl (16|M0)              r111.0<1>:q   r99.0<2;1,0>:d    2:w              
        shl (16|M16)             r113.0<1>:q   r101.0<2;1,0>:d   2:w              
        add (16|M0)              r115.0<1>:q   r95.0<1;1,0>:q    r3.3<0;1,0>:q    {Compacted}
        add (16|M16)             r117.0<1>:q   r97.0<1;1,0>:q    r3.3<0;1,0>:q    {Compacted}
        send.ugm (32|M0)         r21      r115  null:0  0x0            0x08200580           {I@1,$9} // wr:4+0, rd:2; load.ugm.d32.a64
        add (16|M0)              r15.0<1>:q    r111.0<1;1,0>:q   r3.3<0;1,0>:q    {Compacted,$3.src}
        add (16|M16)             r17.0<1>:q    r113.0<1;1,0>:q   r3.3<0;1,0>:q    {Compacted}
        send.ugm (32|M0)         r25      r15  null:0  0x0            0x08200580           {I@1,$10} // wr:4+0, rd:2; load.ugm.d32.a64
(W)     mov (1|M0)               r5.0<1>:f     0.0:f                               {Compacted}
(W)     mov (1|M0)               r4.3<1>:f     0.0162:f                              
(W)     mul (16|M0)              acc0.0<1>:d   r13.0<1;1,0>:d    r4.4<0;1,0>:uw  
        macl (16|M0)             r23.0<1>:d    r13.0<1;1,0>:d    r4.2<0;1,0>:d    {Compacted}
(W)     mul (16|M16)             acc0.0<1>:d   r14.0<1;1,0>:d    r4.4<0;1,0>:uw  
(W)     mov (1|M0)               r6.0<1>:f     0.054:f                              
        macl (16|M16)            r24.0<1>:d    r14.0<1;1,0>:d    r4.2<0;1,0>:d    {Compacted}
        mad (32|M0)              acc0.0<1>:f   r5.0<0;0>:f       r19.0<1;0>:f      r4.3<0>:f        {Compacted,A@1,$2.dst}
(W)     mov (1|M0)               r8.0<1>:f     0.1216:f                              
        mad (32|M0)              acc0.0<1>:f   acc0.0<1;0>:f     r41.0<1;0>:f      r6.0<0>:f        {Compacted,@3,$3.dst}
(W)     mov (1|M0)               r10.0<1>:f    0.1945:f                              
        mad (32|M0)              acc0.0<1>:f   acc0.0<1;0>:f     r59.0<1;0>:f      r8.0<0>:f        {Compacted,@3,$4.dst}
(W)     mov (1|M0)               r12.0<1>:f    0.227:f                              
        mad (32|M0)              acc0.0<1>:f   acc0.0<1;0>:f     r77.0<1;0>:f      r10.0<0>:f       {Compacted,@3,$5.dst}
        mad (32|M0)              acc0.0<1>:f   acc0.0<1;0>:f     r93.0<1;0>:f      r12.0<0>:f       {Compacted,@2,$6.dst}
        add (32|M0)              r27.0<1>:d    r23.0<1;1,0>:d    r121.0<1;1,0>:d  {Compacted}
        mad (32|M0)              acc0.0<1>:f   acc0.0<1;0>:f     r109.0<1;0>:f     r10.0<0>:f       {Compacted,$7.dst}
        mov (16|M0)              r29.0<2>:ud   r27.0<1;1,0>:ud                  {Compacted,I@1}
        mov (16|M16)             r31.0<2>:ud   r28.0<1;1,0>:ud                  {Compacted}
        mad (32|M0)              acc0.0<1>:f   acc0.0<1;0>:f     r119.0<1;0>:f     r8.0<0>:f        {$8.dst}
        shl (16|M0)              r33.0<1>:q    r29.0<2;1,0>:d    2:w               {I@2}
        shl (16|M16)             r35.0<1>:q    r31.0<2;1,0>:d    2:w               {I@2}
        mad (32|M0)              acc0.0<1>:f   acc0.0<1;0>:f     r21.0<1;0>:f      r6.0<0>:f        {Compacted,$9.dst}
        add (16|M0)              r37.0<1>:q    r33.0<1;1,0>:q    r4.0<0;1,0>:q    {Compacted,I@2}
        add (16|M16)             r39.0<1>:q    r35.0<1;1,0>:q    r4.0<0;1,0>:q    {Compacted,I@2}
        mad (32|M0)              r41.0<1>:f    acc0.0<1;0>:f     r25.0<1;0>:f      r4.3<0>:f        {Compacted,$10.dst}
        send.ugm (32|M0)         null     r37  r41:2  0x0            0x08000584           {A@1,$11} // wr:4+2, rd:0; store.ugm.d32.a64
        join (32|M0)                         16                                
(W)     mov (16|M0)              r127.0<1>:f   r7.0<1;1,0>:f                   
(W)     send.gtwy (1|M0)         null     r127  null:0  0x0            0x02000010           {EOT,F@1,$12} // wr:1+0, rd:0; end of thread
(W)     mov (16|M0)              null<1>:ud    0xC98FA22F:ud                             
(W)     mov (16|M0)              null<1>:ud    0x330C2E64:ud                             
(W)     mov (16|M0)              null<1>:ud    0x0:ud                             
(W)     mov (16|M0)              null<1>:ud    0xB:ud                             
        illegal                
        illegal                
        illegal                
        illegal                
        illegal                
        illegal                
        illegal                
        illegal                
        illegal                
