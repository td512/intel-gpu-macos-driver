(W)     mov (16|M0)              r127.0<1>:ud  0x0:ud                             
(W)     and (1|M0)               r127.2<1>:ud  r0.0<0;1,0>:ud    0xFFFFFFC0:ud             
(W)     and (1|M0)               r127.0<1>:uw  r0.4<0;1,0>:uw    0xFF:uw             
(W)     add (1|M0)               r127.2<1>:ud  r127.2<0;1,0>:ud  0x40:ud              {I@2}
(W)     add (1|M0)               r127.2<1>:ud  r127.2<0;1,0>:ud  0x0:ud              {I@1}
(W)     mad (1|M0)               r127.0<1>:ud  r127.2<0;0>:ud    r127.0<0;0>:uw    0xC0:uw              {I@1}
(W)     mov (8|M0)               r4.0<1>:ud    r1.0<1;1,0>:ud                  
(W)     send.ugm (1|M0)          r1       r127  null:0  0xFF000000            0x6229E500           {A@1,$0} // wr:1+0, rd:2; load.ugm.d32x32t.a32.ca.cc.bti[255]
(W)     send.ugm (1|M0)          r3       r127  null:0  0xFF080000            0x6219D500           {$1} // wr:1+0, rd:1; load.ugm.d32x16t.a32.ca.cc.bti[255][A+0x80]
        nop                    
        nop                    
        nop                    
(W)     and (1|M0)               r127.0<1>:ud  r0.0<0;1,0>:ud    0xFFFFFFC0:ud              {$1.src}
(W)     add (1|M0)               r127.0<1>:ud  r127.0<0;1,0>:ud  0x0:ud              {I@1}
(W)     send.ugm (1|M0)          r5       r127  null:0  0xFF000000            0x6219D500           {I@1,$2} // wr:1+0, rd:1; load.ugm.d32x16t.a32.ca.cc.bti[255]
(W)     mov (16|M0)              r42.0<1>:ud   r0.0<1;1,0>:ud                  
(W)     or (1|M0)                cr0.0<1>:ud   cr0.0<0;1,0>:ud   0x400004C0:ud              {A@1}
(W)     mul (1|M0)               acc0.0<1>:d   r4.3<0;1,0>:d     r42.2<0;1,0>:uw  {A@1}
(W)     macl (1|M0)              r6.0<1>:d     r4.3<0;1,0>:d     r42.1<0;1,0>:d  
        add3 (32|M0)             r43.0<1>:d    r6.0<0;0>:d       r1.0<1;0>:uw      r4.0<0>:d        {@1,$0.dst}
        cmp (32|M0)   (lt)f0.0   null<1>:d     r43.0<1;1,0>:d    r5.6<0;1,0>:d    {@1,$2.dst}
(~f0.0) goto (32|M0)                         3856                  3856                
(W)     mul (1|M0)               acc0.0<1>:d   r4.4<0;1,0>:d     r42.12<0;1,0>:uw
(W)     macl (1|M0)              r1.0<1>:d     r4.4<0;1,0>:d     r42.6<0;1,0>:d  
(W)     mul (1|M0)               acc0.0<1>:d   r4.5<0;1,0>:d     r42.14<0;1,0>:uw
        add (32|M0)              r45.0<1>:d    r1.0<0;1,0>:d     r2.0<1;1,0>:uw   {I@2}
        add3 (32|M0)             r47.0<1>:d    r1.0<0;0>:d       r2.0<1;0>:uw      r4.1<0>:d       
(W)     macl (1|M0)              r2.0<1>:d     r4.5<0;1,0>:d     r42.7<0;1,0>:d  
        add3 (32|M0)             r51.0<1>:d    r2.0<0;0>:d       r3.0<1;0>:uw      r4.2<0>:d        {@1,$1.dst}
        cmp (32|M0)   (lt)f0.0   null<1>:d     r51.0<1;1,0>:d    1:w               {I@1}
(~f0.0) cmp (32|M0)   (lt)f0.0   null<1>:d     r47.0<1;1,0>:d    1:w              
        add (32|M0)              r49.0<1>:d    r2.0<0;1,0>:d     r3.0<1;1,0>:uw  
(~f0.0) cmp (32|M0)   (gt)f0.0   null<1>:d     r47.0<1;1,0>:d    r5.4<0;1,0>:d   
        add3 (32|M0)             r6.0<1>:d     r49.0<1;0>:d      r4.2<0;0>:d       -1:w               {I@2}
(~f0.0) cmp (32|M0)   (gt)f0.0   null<1>:d     r51.0<1;1,0>:d    r5.5<0;1,0>:d   
(W)     mul (16|M0)              acc0.0<1>:d   r6.0<1;1,0>:d     r5.8<0;1,0>:uw   {I@2}
        macl (16|M0)             r54.0<1>:d    r6.0<1;1,0>:d     r5.4<0;1,0>:d    {Compacted}
(W)     mul (16|M16)             acc0.0<1>:d   r7.0<1;1,0>:d     r5.8<0;1,0>:uw  
        macl (16|M16)            r55.0<1>:d    r7.0<1;1,0>:d     r5.4<0;1,0>:d    {Compacted}
(f0.0)  goto (32|M0)                         304                  304                
        add3 (32|M0)             r1.0<1>:d     r47.0<1;0>:d      r54.0<1;0>:d      -1:w               {I@2}
(W)     mul (16|M0)              acc0.0<1>:d   r1.0<1;1,0>:d     r5.12<0;1,0>:uw  {I@1}
        macl (16|M0)             r15.0<1>:d    r1.0<1;1,0>:d     r5.6<0;1,0>:d    {Compacted}
(W)     mul (16|M16)             acc0.0<1>:d   r2.0<1;1,0>:d     r5.12<0;1,0>:uw 
        macl (16|M16)            r16.0<1>:d    r2.0<1;1,0>:d     r5.6<0;1,0>:d    {Compacted}
        add (32|M0)              r23.0<1>:d    r15.0<1;1,0>:d    r43.0<1;1,0>:d   {Compacted,I@1}
        mov (16|M0)              r6.0<2>:ud    r43.0<1;1,0>:ud                  {Compacted}
        mov (16|M16)             r8.0<2>:ud    r44.0<1;1,0>:ud                  {Compacted}
        mov (16|M0)              r25.0<2>:ud   r23.0<1;1,0>:ud                  {Compacted,I@3}
        mov (16|M16)             r27.0<2>:ud   r24.0<1;1,0>:ud                 
        shl (16|M0)              r11.0<1>:q    r6.0<2;1,0>:d     2:w               {I@4}
        shl (16|M16)             r13.0<1>:q    r8.0<2;1,0>:d     2:w               {I@4}
        shl (16|M0)              r29.0<1>:q    r25.0<2;1,0>:d    2:w               {I@4}
        shl (16|M16)             r31.0<1>:q    r27.0<2;1,0>:d    2:w               {I@4}
        add (16|M0)              r17.0<1>:q    r11.0<1;1,0>:q    r5.0<0;1,0>:q    {Compacted,I@4}
        add (16|M16)             r19.0<1>:q    r13.0<1;1,0>:q    r5.0<0;1,0>:q    {Compacted,I@4}
        add (16|M0)              r33.0<1>:q    r29.0<1;1,0>:q    r4.3<0;1,0>:q    {Compacted,I@4}
        add (16|M16)             r35.0<1>:q    r31.0<1;1,0>:q    r4.3<0;1,0>:q    {Compacted,I@4}
        send.ugm (32|M0)         r21      r17  null:0  0x0            0x08200580           {I@3,$3} // wr:4+0, rd:2; load.ugm.d32.a64
        send.ugm (32|M0)         r38      r33  null:0  0x0            0x08200580           {I@1,$4} // wr:4+0, rd:2; load.ugm.d32.a64
(W)     mov (1|M0)               r10.0<1>:f    0.0:f                               {Compacted}
        sync.nop                             null                             {Compacted,$4.dst}
        mad (32|M0)              r60.0<1>:f    r10.0<0;0>:f      r21.0<1;0>:f      r38.0<1>:f       {@1,$3.dst}
        goto (32|M0)                         16                  48                
        join (32|M0)                         32                                
        mov (32|M0)              r60.0<1>:ud   0x0:ud                              {F@1}
        join (32|M0)                         3248                                
        cmp (32|M0)   (lt)f3.0   null<1>:d     r51.0<1;1,0>:d    1:w              
(~f3.0) cmp (32|M0)   (lt)f3.0   null<1>:d     r47.0<1;1,0>:d    0:w              
(~f3.0) cmp (32|M0)   (ge)f3.0   null<1>:d     r47.0<1;1,0>:d    r5.4<0;1,0>:d   
(~f3.0) cmp (32|M0)   (gt)f3.0   null<1>:d     r51.0<1;1,0>:d    r5.5<0;1,0>:d   
(f3.0)  goto (32|M0)                         272                  272                
        add (32|M0)              r1.0<1>:d     r47.0<1;1,0>:d    r54.0<1;1,0>:d   {Compacted}
(W)     mul (16|M0)              acc0.0<1>:d   r1.0<1;1,0>:d     r5.12<0;1,0>:uw  {I@1}
        macl (16|M0)             r12.0<1>:d    r1.0<1;1,0>:d     r5.6<0;1,0>:d    {Compacted}
(W)     mul (16|M16)             acc0.0<1>:d   r2.0<1;1,0>:d     r5.12<0;1,0>:uw 
        macl (16|M16)            r13.0<1>:d    r2.0<1;1,0>:d     r5.6<0;1,0>:d    {Compacted}
        add (32|M0)              r6.0<1>:d     r43.0<1;1,0>:d    r5.6<0;1,0>:d    {Compacted}
        add (32|M0)              r22.0<1>:d    r12.0<1;1,0>:d    r43.0<1;1,0>:d   {Compacted,I@2}
        mov (16|M0)              r8.0<2>:ud    r6.0<1;1,0>:ud                   {Compacted,I@2}
        mov (16|M16)             r10.0<2>:ud   r7.0<1;1,0>:ud                   {Compacted}
        mov (16|M0)              r27.0<2>:ud   r22.0<1;1,0>:ud                  {Compacted,I@3}
        mov (16|M16)             r29.0<2>:ud   r23.0<1;1,0>:ud                 
        shl (16|M0)              r14.0<1>:q    r8.0<2;1,0>:d     2:w               {I@4}
        shl (16|M16)             r16.0<1>:q    r10.0<2;1,0>:d    2:w               {I@4}
        shl (16|M0)              r31.0<1>:q    r27.0<2;1,0>:d    2:w               {I@4}
        shl (16|M16)             r33.0<1>:q    r29.0<2;1,0>:d    2:w               {I@4}
        add (16|M0)              r18.0<1>:q    r14.0<1;1,0>:q    r5.0<0;1,0>:q    {Compacted,I@4}
        add (16|M16)             r20.0<1>:q    r16.0<1;1,0>:q    r5.0<0;1,0>:q    {Compacted,I@4}
        add (16|M0)              r35.0<1>:q    r31.0<1;1,0>:q    r4.3<0;1,0>:q    {Compacted,I@4}
        add (16|M16)             r37.0<1>:q    r33.0<1;1,0>:q    r4.3<0;1,0>:q    {Compacted,I@4}
        send.ugm (32|M0)         r25      r18  null:0  0x0            0x08200580           {I@3,$5} // wr:4+0, rd:2; load.ugm.d32.a64
        send.ugm (32|M0)         r40      r35  null:0  0x0            0x08200580           {I@1,$6} // wr:4+0, rd:2; load.ugm.d32.a64
        sync.nop                             null                             {Compacted,$6.dst}
        mad (32|M0)              r60.0<1>:f    r60.0<1;0>:f      r25.0<1;0>:f      r40.0<1>:f       {Compacted,$5.dst}
        join (32|M0)                         2896                                
        cmp (32|M0)   (lt)f2.0   null<1>:d     r51.0<1;1,0>:d    1:w              
(~f2.0) cmp (32|M0)   (lt)f2.0   null<1>:d     r47.0<1;1,0>:d    -1:w              
        add3 (32|M0)             r57.0<1>:d    r45.0<1;0>:d      r4.1<0;0>:d       2:w              
(~f2.0) cmp (32|M0)   (gt)f2.0   null<1>:d     r57.0<1;1,0>:d    r5.4<0;1,0>:d    {I@1}
(~f2.0) cmp (32|M0)   (gt)f2.0   null<1>:d     r51.0<1;1,0>:d    r5.5<0;1,0>:d   
(f2.0)  goto (32|M0)                         288                  288                
        add3 (32|M0)             r1.0<1>:d     r57.0<1;0>:d      r54.0<1;0>:d      -1:w              
(W)     mul (16|M0)              acc0.0<1>:d   r1.0<1;1,0>:d     r5.12<0;1,0>:uw  {I@1}
        macl (16|M0)             r8.0<1>:d     r1.0<1;1,0>:d     r5.6<0;1,0>:d    {Compacted}
(W)     mul (16|M16)             acc0.0<1>:d   r2.0<1;1,0>:d     r5.12<0;1,0>:uw 
(W)     shl (1|M0)               r3.0<1>:d     r5.6<0;1,0>:d     1:w               {Compacted}
        macl (16|M16)            r9.0<1>:d     r2.0<1;1,0>:d     r5.6<0;1,0>:d    {Compacted}
        add (32|M0)              r6.0<1>:d     r3.0<0;1,0>:d     r43.0<1;1,0>:d   {Compacted,I@2}
        add (32|M0)              r16.0<1>:d    r8.0<1;1,0>:d     r43.0<1;1,0>:d   {Compacted,I@2}
        mov (16|M0)              r10.0<2>:ud   r6.0<1;1,0>:ud                   {Compacted,I@2}
        mov (16|M16)             r12.0<2>:ud   r7.0<1;1,0>:ud                   {Compacted}
        mov (16|M0)              r24.0<2>:ud   r16.0<1;1,0>:ud                  {Compacted,A@1}
        mov (16|M16)             r26.0<2>:ud   r17.0<1;1,0>:ud                 
        shl (16|M0)              r14.0<1>:q    r10.0<2;1,0>:d    2:w               {I@4}
        shl (16|M16)             r18.0<1>:q    r12.0<2;1,0>:d    2:w               {I@4}
        shl (16|M0)              r28.0<1>:q    r24.0<2;1,0>:d    2:w               {I@4}
        shl (16|M16)             r30.0<1>:q    r26.0<2;1,0>:d    2:w               {I@4}
        add (16|M0)              r20.0<1>:q    r14.0<1;1,0>:q    r5.0<0;1,0>:q    {Compacted,I@4}
        add (16|M16)             r22.0<1>:q    r18.0<1;1,0>:q    r5.0<0;1,0>:q    {Compacted,I@4}
        add (16|M0)              r35.0<1>:q    r28.0<1;1,0>:q    r4.3<0;1,0>:q    {Compacted,I@4}
        add (16|M16)             r37.0<1>:q    r30.0<1;1,0>:q    r4.3<0;1,0>:q    {Compacted,I@4}
        send.ugm (32|M0)         r33      r20  null:0  0x0            0x08200580           {I@3,$7} // wr:4+0, rd:2; load.ugm.d32.a64
        send.ugm (32|M0)         r40      r35  null:0  0x0            0x08200580           {I@1,$8} // wr:4+0, rd:2; load.ugm.d32.a64
        sync.nop                             null                             {Compacted,$8.dst}
        mad (32|M0)              r60.0<1>:f    r60.0<1;0>:f      r33.0<1;0>:f      r40.0<1>:f       {Compacted,$7.dst}
        join (32|M0)                         2512                                
        cmp (32|M0)   (lt)f1.0   null<1>:d     r51.0<1;1,0>:d    0:w              
(~f1.0) cmp (32|M0)   (lt)f1.0   null<1>:d     r47.0<1;1,0>:d    1:w              
(~f1.0) cmp (32|M0)   (gt)f1.0   null<1>:d     r47.0<1;1,0>:d    r5.4<0;1,0>:d   
(~f1.0) cmp (32|M0)   (ge)f1.0   null<1>:d     r51.0<1;1,0>:d    r5.5<0;1,0>:d   
(W)     mul (16|M0)              acc0.0<1>:d   r51.0<1;1,0>:d    r5.8<0;1,0>:uw  
        macl (16|M0)             r62.0<1>:d    r51.0<1;1,0>:d    r5.4<0;1,0>:d   
(W)     mul (16|M16)             acc0.0<1>:d   r52.0<1;1,0>:d    r5.8<0;1,0>:uw  
        macl (16|M16)            r63.0<1>:d    r52.0<1;1,0>:d    r5.4<0;1,0>:d   
(f1.0)  goto (32|M0)                         288                  288                
        add3 (32|M0)             r1.0<1>:d     r47.0<1;0>:d      r62.0<1;0>:d      -1:w               {I@2}
(W)     mul (16|M0)              acc0.0<1>:d   r1.0<1;1,0>:d     r5.12<0;1,0>:uw  {I@1}
        macl (16|M0)             r12.0<1>:d    r1.0<1;1,0>:d     r5.6<0;1,0>:d    {Compacted}
(W)     mul (16|M16)             acc0.0<1>:d   r2.0<1;1,0>:d     r5.12<0;1,0>:uw 
        macl (16|M16)            r13.0<1>:d    r2.0<1;1,0>:d     r5.6<0;1,0>:d    {Compacted}
        add (32|M0)              r22.0<1>:d    r12.0<1;1,0>:d    r43.0<1;1,0>:d   {I@1}
        mad (32|M0)              r6.0<1>:d     r43.0<1;0>:d      r5.6<0;0>:d       3:w              
        mov (16|M0)              r27.0<2>:ud   r22.0<1;1,0>:ud                  {Compacted,I@2}
        mov (16|M16)             r29.0<2>:ud   r23.0<1;1,0>:ud                  {Compacted}
        mov (16|M0)              r8.0<2>:ud    r6.0<1;1,0>:ud                   {Compacted,I@3}
        mov (16|M16)             r10.0<2>:ud   r7.0<1;1,0>:ud                   {Compacted}
        shl (16|M0)              r31.0<1>:q    r27.0<2;1,0>:d    2:w               {I@4}
        shl (16|M16)             r33.0<1>:q    r29.0<2;1,0>:d    2:w               {A@1}
        shl (16|M0)              r14.0<1>:q    r8.0<2;1,0>:d     2:w               {I@4}
        shl (16|M16)             r16.0<1>:q    r10.0<2;1,0>:d    2:w               {I@4}
        add (16|M0)              r35.0<1>:q    r31.0<1;1,0>:q    r4.3<0;1,0>:q    {Compacted,I@4}
        add (16|M16)             r37.0<1>:q    r33.0<1;1,0>:q    r4.3<0;1,0>:q    {Compacted,I@4}
        add (16|M0)              r18.0<1>:q    r14.0<1;1,0>:q    r5.0<0;1,0>:q    {Compacted,I@4}
        add (16|M16)             r20.0<1>:q    r16.0<1;1,0>:q    r5.0<0;1,0>:q    {Compacted,I@4}
        send.ugm (32|M0)         r40      r35  null:0  0x0            0x08200580           {I@3,$9} // wr:4+0, rd:2; load.ugm.d32.a64
        send.ugm (32|M0)         r25      r18  null:0  0x0            0x08200580           {I@1,$10} // wr:4+0, rd:2; load.ugm.d32.a64
        sync.nop                             null                             {Compacted,$10.dst}
        mad (32|M0)              r60.0<1>:f    r60.0<1;0>:f      r25.0<1;0>:f      r40.0<1>:f       {Compacted,$9.dst}
        join (32|M0)                         2080                                
        cmp (32|M0)   (ge)f1.0   null<1>:d     r47.0<1;1,0>:d    r5.4<0;1,0>:d   
        or (32|M0)               r1.0<1>:d     r47.0<1;1,0>:d    r51.0<1;1,0>:d  
(~f1.0) cmp (32|M0)   (lt)f1.0   null<1>:d     r1.0<1;1,0>:d     0:w               {I@1}
(~f1.0) cmp (32|M0)   (ge)f1.0   null<1>:d     r51.0<1;1,0>:d    r5.5<0;1,0>:d   
(f1.0)  goto (32|M0)                         272                  272                
        add (32|M0)              r1.0<1>:d     r47.0<1;1,0>:d    r62.0<1;1,0>:d   {Compacted}
(W)     mul (16|M0)              acc0.0<1>:d   r1.0<1;1,0>:d     r5.12<0;1,0>:uw  {I@1}
        macl (16|M0)             r8.0<1>:d     r1.0<1;1,0>:d     r5.6<0;1,0>:d    {Compacted}
(W)     mul (16|M16)             acc0.0<1>:d   r2.0<1;1,0>:d     r5.12<0;1,0>:uw 
(W)     shl (1|M0)               r3.0<1>:d     r5.6<0;1,0>:d     2:w               {Compacted}
        macl (16|M16)            r9.0<1>:d     r2.0<1;1,0>:d     r5.6<0;1,0>:d    {Compacted}
        add (32|M0)              r6.0<1>:d     r3.0<0;1,0>:d     r43.0<1;1,0>:d   {Compacted,I@2}
        add (32|M0)              r16.0<1>:d    r8.0<1;1,0>:d     r43.0<1;1,0>:d   {Compacted,I@2}
        mov (16|M0)              r10.0<2>:ud   r6.0<1;1,0>:ud                   {Compacted,I@2}
        mov (16|M16)             r12.0<2>:ud   r7.0<1;1,0>:ud                   {Compacted}
        mov (16|M0)              r24.0<2>:ud   r16.0<1;1,0>:ud                  {Compacted,A@1}
        mov (16|M16)             r26.0<2>:ud   r17.0<1;1,0>:ud                  {Compacted}
        shl (16|M0)              r14.0<1>:q    r10.0<2;1,0>:d    2:w               {I@4}
        shl (16|M16)             r18.0<1>:q    r12.0<2;1,0>:d    2:w               {I@4}
        shl (16|M0)              r28.0<1>:q    r24.0<2;1,0>:d    2:w               {I@4}
        shl (16|M16)             r30.0<1>:q    r26.0<2;1,0>:d    2:w               {I@4}
        add (16|M0)              r20.0<1>:q    r14.0<1;1,0>:q    r5.0<0;1,0>:q    {Compacted,I@4}
        add (16|M16)             r22.0<1>:q    r18.0<1;1,0>:q    r5.0<0;1,0>:q    {Compacted,I@4}
        add (16|M0)              r35.0<1>:q    r28.0<1;1,0>:q    r4.3<0;1,0>:q    {Compacted,I@4}
        add (16|M16)             r37.0<1>:q    r30.0<1;1,0>:q    r4.3<0;1,0>:q    {Compacted,I@4}
        send.ugm (32|M0)         r33      r20  null:0  0x0            0x08200580           {I@3,$11} // wr:4+0, rd:2; load.ugm.d32.a64
        send.ugm (32|M0)         r40      r35  null:0  0x0            0x08200580           {I@1,$12} // wr:4+0, rd:2; load.ugm.d32.a64
        sync.nop                             null                             {Compacted,$12.dst}
        mad (32|M0)              r60.0<1>:f    r60.0<1;0>:f      r33.0<1;0>:f      r40.0<1>:f       {Compacted,$11.dst}
        join (32|M0)                         1728                                
        cmp (32|M0)   (lt)f0.0   null<1>:d     r51.0<1;1,0>:d    0:w              
(~f0.0) cmp (32|M0)   (lt)f0.0   null<1>:d     r47.0<1;1,0>:d    -1:w              
(~f0.0) cmp (32|M0)   (gt)f0.0   null<1>:d     r57.0<1;1,0>:d    r5.4<0;1,0>:d   
(~f0.0) cmp (32|M0)   (ge)f0.0   null<1>:d     r51.0<1;1,0>:d    r5.5<0;1,0>:d   
(f0.0)  goto (32|M0)                         288                  288                
        add3 (32|M0)             r1.0<1>:d     r57.0<1;0>:d      r62.0<1;0>:d      -1:w              
(W)     mul (16|M0)              acc0.0<1>:d   r1.0<1;1,0>:d     r5.12<0;1,0>:uw  {I@1}
        macl (16|M0)             r12.0<1>:d    r1.0<1;1,0>:d     r5.6<0;1,0>:d    {Compacted}
(W)     mul (16|M16)             acc0.0<1>:d   r2.0<1;1,0>:d     r5.12<0;1,0>:uw 
        macl (16|M16)            r13.0<1>:d    r2.0<1;1,0>:d     r5.6<0;1,0>:d    {Compacted}
        add (32|M0)              r22.0<1>:d    r12.0<1;1,0>:d    r43.0<1;1,0>:d   {Compacted,I@1}
        mad (32|M0)              r6.0<1>:d     r43.0<1;0>:d      r5.6<0;0>:d       5:w              
        mov (16|M0)              r27.0<2>:ud   r22.0<1;1,0>:ud                  {Compacted,I@2}
        mov (16|M16)             r29.0<2>:ud   r23.0<1;1,0>:ud                  {Compacted}
        mov (16|M0)              r8.0<2>:ud    r6.0<1;1,0>:ud                   {Compacted,I@3}
        mov (16|M16)             r10.0<2>:ud   r7.0<1;1,0>:ud                  
        shl (16|M0)              r31.0<1>:q    r27.0<2;1,0>:d    2:w               {I@4}
        shl (16|M16)             r33.0<1>:q    r29.0<2;1,0>:d    2:w               {A@1}
        shl (16|M0)              r14.0<1>:q    r8.0<2;1,0>:d     2:w               {I@4}
        shl (16|M16)             r16.0<1>:q    r10.0<2;1,0>:d    2:w               {I@4}
        add (16|M0)              r35.0<1>:q    r31.0<1;1,0>:q    r4.3<0;1,0>:q    {Compacted,I@4}
        add (16|M16)             r37.0<1>:q    r33.0<1;1,0>:q    r4.3<0;1,0>:q    {Compacted,I@4}
        add (16|M0)              r18.0<1>:q    r14.0<1;1,0>:q    r5.0<0;1,0>:q    {Compacted,I@4}
        add (16|M16)             r20.0<1>:q    r16.0<1;1,0>:q    r5.0<0;1,0>:q    {Compacted,I@4}
        send.ugm (32|M0)         r40      r35  null:0  0x0            0x08200580           {I@3,$13} // wr:4+0, rd:2; load.ugm.d32.a64
        send.ugm (32|M0)         r25      r18  null:0  0x0            0x08200580           {I@1,$14} // wr:4+0, rd:2; load.ugm.d32.a64
        sync.nop                             null                             {Compacted,$14.dst}
        mad (32|M0)              r60.0<1>:f    r60.0<1;0>:f      r25.0<1;0>:f      r40.0<1>:f       {Compacted,$13.dst}
        join (32|M0)                         1360                                
        cmp (32|M0)   (lt)f3.0   null<1>:d     r51.0<1;1,0>:d    -1:w              
(~f3.0) cmp (32|M0)   (lt)f3.0   null<1>:d     r47.0<1;1,0>:d    1:w              
(~f3.0) cmp (32|M0)   (gt)f3.0   null<1>:d     r47.0<1;1,0>:d    r5.4<0;1,0>:d   
        add3 (32|M0)             r64.0<1>:d    r49.0<1;0>:d      r4.2<0;0>:d       2:w              
        add3 (32|M0)             r1.0<1>:d     r49.0<1;0>:d      r4.2<0;0>:d       1:w              
(~f3.0) cmp (32|M0)   (gt)f3.0   null<1>:d     r64.0<1;1,0>:d    r5.5<0;1,0>:d    {I@2}
(W)     mul (16|M0)              acc0.0<1>:d   r1.0<1;1,0>:d     r5.8<0;1,0>:uw   {I@2}
        macl (16|M0)             r66.0<1>:d    r1.0<1;1,0>:d     r5.4<0;1,0>:d    {Compacted}
(W)     mul (16|M16)             acc0.0<1>:d   r2.0<1;1,0>:d     r5.8<0;1,0>:uw  
        macl (16|M16)            r67.0<1>:d    r2.0<1;1,0>:d     r5.4<0;1,0>:d    {Compacted}
(f3.0)  goto (32|M0)                         288                  288                
        add3 (32|M0)             r1.0<1>:d     r47.0<1;0>:d      r66.0<1;0>:d      -1:w               {I@2}
(W)     mul (16|M0)              acc0.0<1>:d   r1.0<1;1,0>:d     r5.12<0;1,0>:uw  {I@1}
        macl (16|M0)             r12.0<1>:d    r1.0<1;1,0>:d     r5.6<0;1,0>:d    {Compacted}
(W)     mul (16|M16)             acc0.0<1>:d   r2.0<1;1,0>:d     r5.12<0;1,0>:uw 
        macl (16|M16)            r13.0<1>:d    r2.0<1;1,0>:d     r5.6<0;1,0>:d    {Compacted}
        add (32|M0)              r22.0<1>:d    r12.0<1;1,0>:d    r43.0<1;1,0>:d   {Compacted,I@1}
        mad (32|M0)              r6.0<1>:d     r43.0<1;0>:d      r5.6<0;0>:d       6:w              
        mov (16|M0)              r27.0<2>:ud   r22.0<1;1,0>:ud                  {Compacted,I@2}
        mov (16|M16)             r29.0<2>:ud   r23.0<1;1,0>:ud                  {Compacted}
        mov (16|M0)              r8.0<2>:ud    r6.0<1;1,0>:ud                   {Compacted,I@3}
        mov (16|M16)             r10.0<2>:ud   r7.0<1;1,0>:ud                  
        shl (16|M0)              r31.0<1>:q    r27.0<2;1,0>:d    2:w               {I@4}
        shl (16|M16)             r33.0<1>:q    r29.0<2;1,0>:d    2:w               {I@4}
        shl (16|M0)              r14.0<1>:q    r8.0<2;1,0>:d     2:w               {I@4}
        shl (16|M16)             r16.0<1>:q    r10.0<2;1,0>:d    2:w               {I@4}
        add (16|M0)              r35.0<1>:q    r31.0<1;1,0>:q    r4.3<0;1,0>:q    {Compacted,I@4}
        add (16|M16)             r37.0<1>:q    r33.0<1;1,0>:q    r4.3<0;1,0>:q    {Compacted,I@4}
        add (16|M0)              r18.0<1>:q    r14.0<1;1,0>:q    r5.0<0;1,0>:q    {Compacted,I@4}
        add (16|M16)             r20.0<1>:q    r16.0<1;1,0>:q    r5.0<0;1,0>:q    {Compacted,I@4}
        send.ugm (32|M0)         r40      r35  null:0  0x0            0x08200580           {A@1,$15} // wr:4+0, rd:2; load.ugm.d32.a64
        send.ugm (32|M0)         r25      r18  null:0  0x0            0x08200580           {I@1,$0} // wr:4+0, rd:2; load.ugm.d32.a64
        sync.nop                             null                             {Compacted,$0.dst}
        mad (32|M0)              r60.0<1>:f    r60.0<1;0>:f      r25.0<1;0>:f      r40.0<1>:f       {Compacted,$15.dst}
        join (32|M0)                         912                                
        cmp (32|M0)   (lt)f2.0   null<1>:d     r51.0<1;1,0>:d    -1:w              
(~f2.0) cmp (32|M0)   (lt)f2.0   null<1>:d     r47.0<1;1,0>:d    0:w              
(~f2.0) cmp (32|M0)   (ge)f2.0   null<1>:d     r47.0<1;1,0>:d    r5.4<0;1,0>:d   
(~f2.0) cmp (32|M0)   (gt)f2.0   null<1>:d     r64.0<1;1,0>:d    r5.5<0;1,0>:d   
(f2.0)  goto (32|M0)                         288                  288                
        add (32|M0)              r1.0<1>:d     r47.0<1;1,0>:d    r66.0<1;1,0>:d  
(W)     mul (16|M0)              acc0.0<1>:d   r1.0<1;1,0>:d     r5.12<0;1,0>:uw  {I@1}
        macl (16|M0)             r12.0<1>:d    r1.0<1;1,0>:d     r5.6<0;1,0>:d    {Compacted}
(W)     mul (16|M16)             acc0.0<1>:d   r2.0<1;1,0>:d     r5.12<0;1,0>:uw 
        macl (16|M16)            r13.0<1>:d    r2.0<1;1,0>:d     r5.6<0;1,0>:d    {Compacted}
        add (32|M0)              r22.0<1>:d    r12.0<1;1,0>:d    r43.0<1;1,0>:d   {I@1}
        mad (32|M0)              r6.0<1>:d     r43.0<1;0>:d      r5.6<0;0>:d       7:w              
        mov (16|M0)              r27.0<2>:ud   r22.0<1;1,0>:ud                  {Compacted,I@2}
        mov (16|M16)             r29.0<2>:ud   r23.0<1;1,0>:ud                  {Compacted}
        mov (16|M0)              r8.0<2>:ud    r6.0<1;1,0>:ud                   {Compacted,I@3}
        mov (16|M16)             r10.0<2>:ud   r7.0<1;1,0>:ud                   {Compacted}
        shl (16|M0)              r31.0<1>:q    r27.0<2;1,0>:d    2:w               {I@4}
        shl (16|M16)             r33.0<1>:q    r29.0<2;1,0>:d    2:w               {I@4}
        shl (16|M0)              r14.0<1>:q    r8.0<2;1,0>:d     2:w               {I@4}
        shl (16|M16)             r16.0<1>:q    r10.0<2;1,0>:d    2:w               {I@4}
        add (16|M0)              r35.0<1>:q    r31.0<1;1,0>:q    r4.3<0;1,0>:q    {Compacted,I@4}
        add (16|M16)             r37.0<1>:q    r33.0<1;1,0>:q    r4.3<0;1,0>:q    {Compacted,I@4}
        add (16|M0)              r18.0<1>:q    r14.0<1;1,0>:q    r5.0<0;1,0>:q    {Compacted,I@4}
        add (16|M16)             r20.0<1>:q    r16.0<1;1,0>:q    r5.0<0;1,0>:q    {Compacted,I@4}
        send.ugm (32|M0)         r40      r35  null:0  0x0            0x08200580           {A@1,$1} // wr:4+0, rd:2; load.ugm.d32.a64
        send.ugm (32|M0)         r25      r18  null:0  0x0            0x08200580           {I@1,$2} // wr:4+0, rd:2; load.ugm.d32.a64
        sync.nop                             null                             {Compacted,$2.dst}
        mad (32|M0)              r60.0<1>:f    r60.0<1;0>:f      r25.0<1;0>:f      r40.0<1>:f       {Compacted,$1.dst}
        join (32|M0)                         544                                
        cmp (32|M0)   (lt)f1.0   null<1>:d     r51.0<1;1,0>:d    -1:w              
(~f1.0) cmp (32|M0)   (lt)f1.0   null<1>:d     r47.0<1;1,0>:d    -1:w              
(~f1.0) cmp (32|M0)   (gt)f1.0   null<1>:d     r57.0<1;1,0>:d    r5.4<0;1,0>:d   
(~f1.0) cmp (32|M0)   (gt)f1.0   null<1>:d     r64.0<1;1,0>:d    r5.5<0;1,0>:d   
(f1.0)  goto (32|M0)                         288                  288                
        add3 (32|M0)             r1.0<1>:d     r57.0<1;0>:d      r66.0<1;0>:d      -1:w              
(W)     mul (16|M0)              acc0.0<1>:d   r1.0<1;1,0>:d     r5.12<0;1,0>:uw  {I@1}
        macl (16|M0)             r8.0<1>:d     r1.0<1;1,0>:d     r5.6<0;1,0>:d    {Compacted}
(W)     mul (16|M16)             acc0.0<1>:d   r2.0<1;1,0>:d     r5.12<0;1,0>:uw 
(W)     shl (1|M0)               r3.0<1>:d     r5.6<0;1,0>:d     3:w               {Compacted}
        macl (16|M16)            r9.0<1>:d     r2.0<1;1,0>:d     r5.6<0;1,0>:d    {Compacted}
        add (32|M0)              r6.0<1>:d     r3.0<0;1,0>:d     r43.0<1;1,0>:d   {Compacted,I@2}
        add (32|M0)              r16.0<1>:d    r8.0<1;1,0>:d     r43.0<1;1,0>:d   {Compacted,I@2}
        mov (16|M0)              r10.0<2>:ud   r6.0<1;1,0>:ud                   {Compacted,I@2}
        mov (16|M16)             r12.0<2>:ud   r7.0<1;1,0>:ud                   {Compacted}
        mov (16|M0)              r24.0<2>:ud   r16.0<1;1,0>:ud                  {Compacted,A@1}
        mov (16|M16)             r26.0<2>:ud   r17.0<1;1,0>:ud                 
        shl (16|M0)              r14.0<1>:q    r10.0<2;1,0>:d    2:w               {I@4}
        shl (16|M16)             r18.0<1>:q    r12.0<2;1,0>:d    2:w               {I@4}
        shl (16|M0)              r28.0<1>:q    r24.0<2;1,0>:d    2:w               {I@4}
        shl (16|M16)             r30.0<1>:q    r26.0<2;1,0>:d    2:w               {I@4}
        add (16|M0)              r20.0<1>:q    r14.0<1;1,0>:q    r5.0<0;1,0>:q    {Compacted,I@4}
        add (16|M16)             r22.0<1>:q    r18.0<1;1,0>:q    r5.0<0;1,0>:q    {Compacted,I@4}
        add (16|M0)              r35.0<1>:q    r28.0<1;1,0>:q    r4.3<0;1,0>:q    {Compacted,I@4}
        add (16|M16)             r37.0<1>:q    r30.0<1;1,0>:q    r4.3<0;1,0>:q    {Compacted,I@4}
        send.ugm (32|M0)         r33      r20  null:0  0x0            0x08200580           {I@3,$3} // wr:4+0, rd:2; load.ugm.d32.a64
        send.ugm (32|M0)         r40      r35  null:0  0x0            0x08200580           {I@1,$4} // wr:4+0, rd:2; load.ugm.d32.a64
        sync.nop                             null                             {Compacted,$4.dst}
        mad (32|M0)              r60.0<1>:f    r60.0<1;0>:f      r33.0<1;0>:f      r40.0<1>:f       {Compacted,$3.dst}
        join (32|M0)                         176                                
        add (32|M0)              r3.0<1>:d     r62.0<1;1,0>:d    r47.0<1;1,0>:d   {Compacted}
(W)     mul (16|M0)              acc0.0<1>:d   r3.0<1;1,0>:d     r5.12<0;1,0>:uw  {I@1}
        macl (16|M0)             r6.0<1>:d     r3.0<1;1,0>:d     r5.6<0;1,0>:d    {Compacted}
(W)     mul (16|M16)             acc0.0<1>:d   r4.0<1;1,0>:d     r5.12<0;1,0>:uw 
        macl (16|M16)            r7.0<1>:d     r4.0<1;1,0>:d     r5.6<0;1,0>:d    {Compacted}
        add (32|M0)              r8.0<1>:d     r6.0<1;1,0>:d     r43.0<1;1,0>:d   {Compacted,I@1}
        mov (16|M0)              r10.0<2>:ud   r8.0<1;1,0>:ud                   {Compacted,I@1}
        mov (16|M16)             r14.0<2>:ud   r9.0<1;1,0>:ud                   {Compacted}
        shl (16|M0)              r12.0<1>:q    r10.0<2;1,0>:d    2:w               {I@2}
        shl (16|M16)             r16.0<1>:q    r14.0<2;1,0>:d    2:w               {I@2}
        sel (32|M0)   (ge)f0.0   r1.0<1>:f     r60.0<1;1,0>:f    0.0:f               {F@1}
        add (16|M0)              r18.0<1>:q    r12.0<1;1,0>:q    r5.1<0;1,0>:q    {Compacted,I@2}
        add (16|M16)             r20.0<1>:q    r16.0<1;1,0>:q    r5.1<0;1,0>:q    {Compacted,I@2}
        send.ugm (32|M0)         null     r18  r1:2  0x0            0x08000584           {A@1,$5} // wr:4+2, rd:0; store.ugm.d32.a64
        join (32|M0)                         16                                
(W)     mov (16|M0)              r127.0<1>:f   r42.0<1;1,0>:f                  
(W)     send.gtwy (1|M0)         null     r127  null:0  0x0            0x02000010           {EOT,F@1,$6} // wr:1+0, rd:0; end of thread
(W)     mov (16|M0)              null<1>:ud    0xC98FA22F:ud                             
(W)     mov (16|M0)              null<1>:ud    0x330C2E64:ud                             
(W)     mov (16|M0)              null<1>:ud    0x0:ud                             
(W)     mov (16|M0)              null<1>:ud    0x8:ud                             
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
