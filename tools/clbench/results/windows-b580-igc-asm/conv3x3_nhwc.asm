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
(W)     mov (16|M0)              r26.0<1>:ud   r0.0<1;1,0>:ud                  
(W)     or (1|M0)                cr0.0<1>:ud   cr0.0<0;1,0>:ud   0x400004C0:ud              {A@1}
(W)     mul (1|M0)               acc0.0<1>:d   r4.3<0;1,0>:d     r26.2<0;1,0>:uw  {A@1}
(W)     macl (1|M0)              r6.0<1>:d     r4.3<0;1,0>:d     r26.1<0;1,0>:d  
        add3 (32|M0)             r28.0<1>:d    r6.0<0;0>:d       r1.0<1;0>:uw      r4.0<0>:d        {@1,$0.dst}
        cmp (32|M0)   (lt)f1.0   null<1>:d     r28.0<1;1,0>:d    r5.9<0;1,0>:d    {@1,$2.dst}
(~f1.0) goto (32|M0)                         5320                  5320                
        mov (16|M0)              r10.0<2>:ud   r28.0<1;1,0>:ud                  {Compacted}
        mov (16|M16)             r14.0<2>:ud   r29.0<1;1,0>:ud                  {Compacted}
        shl (16|M0)              r12.0<1>:q    r10.0<2;1,0>:d    2:w               {I@2}
        shl (16|M16)             r16.0<1>:q    r14.0<2;1,0>:d    2:w               {I@2}
        add (16|M0)              r18.0<1>:q    r12.0<1;1,0>:q    r5.1<0;1,0>:q    {Compacted,I@2}
        add (16|M16)             r20.0<1>:q    r16.0<1;1,0>:q    r5.1<0;1,0>:q    {Compacted,I@2}
        send.ugm (32|M0)         r38      r18  null:0  0x0            0x08200580           {I@1,$3} // wr:4+0, rd:2; load.ugm.d32.a64
(W)     mul (1|M0)               acc0.0<1>:d   r4.4<0;1,0>:d     r26.12<0;1,0>:uw
(W)     macl (1|M0)              r7.0<1>:d     r4.4<0;1,0>:d     r26.6<0;1,0>:d  
(W)     mul (1|M0)               acc0.0<1>:d   r4.5<0;1,0>:d     r26.14<0;1,0>:uw
(W)     macl (1|M0)              r9.0<1>:d     r4.5<0;1,0>:d     r26.7<0;1,0>:d  
(W)     cmp (32|M0)   (gt)f0.0   null<1>:d     r5.8<0;1,0>:d     0:w              
        add3 (32|M0)             r36.0<1>:d    r9.0<0;0>:d       r3.0<1;0>:uw      r4.2<0>:d        {@2,$1.dst}
        cmp (32|M0)   (gt)f1.0   null<1>:d     r36.0<1;1,0>:d    r5.7<0;1,0>:d    {I@1}
(~f1.0) cmp (32|M0)   (lt)f1.0   null<1>:d     r36.0<1;1,0>:d    1:w              
        add (32|M0)              r30.0<1>:d    r7.0<0;1,0>:d     r2.0<1;1,0>:uw  
        add3 (32|M0)             r32.0<1>:d    r7.0<0;0>:d       r2.0<1;0>:uw      r4.1<0>:d       
        add (32|M0)              r34.0<1>:d    r9.0<0;1,0>:d     r3.0<1;1,0>:uw  
        add (16|M0)              r52.0<1>:q    r12.0<1;1,0>:q    r5.0<0;1,0>:q    {Compacted}
        add (16|M16)             r54.0<1>:q    r16.0<1;1,0>:q    r5.0<0;1,0>:q    {Compacted}
(f1.0)  goto (32|M0)                         1472                  1472                
        cmp (32|M0)   (gt)f3.0   null<1>:d     r32.0<1;1,0>:d    r5.6<0;1,0>:d    {I@5}
        add3 (32|M0)             r6.0<1>:d     r34.0<1;0>:d      r4.2<0;0>:d       -1:w               {I@5}
(~f3.0) cmp (32|M0)   (lt)f3.0   null<1>:d     r32.0<1;1,0>:d    1:w              
(W)     mul (16|M0)              acc0.0<1>:d   r6.0<1;1,0>:d     r5.12<0;1,0>:uw  {I@2}
        macl (16|M0)             r40.0<1>:d    r6.0<1;1,0>:d     r5.6<0;1,0>:d    {Compacted}
(W)     mul (16|M16)             acc0.0<1>:d   r7.0<1;1,0>:d     r5.12<0;1,0>:uw 
        macl (16|M16)            r41.0<1>:d    r7.0<1;1,0>:d     r5.6<0;1,0>:d    {Compacted}
(f3.0)  goto (32|M0)                         352                  352                
(~f0.0) goto (32|M0)                         336                  336                
        add3 (32|M0)             r6.0<1>:d     r32.0<1;0>:d      r40.0<1;0>:d      -1:w               {I@3}
(W)     mul (16|M0)              acc0.0<1>:d   r6.0<1;1,0>:d     r5.16<0;1,0>:uw  {I@1}
        macl (16|M0)             r8.0<1>:d     r6.0<1;1,0>:d     r5.8<0;1,0>:d    {Compacted}
(W)     mul (16|M16)             acc0.0<1>:d   r7.0<1;1,0>:d     r5.16<0;1,0>:uw 
        macl (16|M16)            r9.0<1>:d     r7.0<1;1,0>:d     r5.8<0;1,0>:d    {Compacted}
        mov (16|M0)              r10.0<2>:ud   r8.0<1;1,0>:ud                   {Compacted,I@3}
        mov (16|M16)             r14.0<2>:ud   r9.0<1;1,0>:ud                   {Compacted,I@2}
        shl (16|M0)              r12.0<1>:q    r10.0<2;1,0>:d    2:w               {I@2}
        shl (16|M16)             r16.0<1>:q    r14.0<2;1,0>:d    2:w               {I@2}
        add (16|M0)              r56.0<1>:q    r12.0<1;1,0>:q    r4.3<0;1,0>:q    {Compacted,I@2}
        add (16|M16)             r58.0<1>:q    r16.0<1;1,0>:q    r4.3<0;1,0>:q    {Compacted,I@2}
(W)     mov (1|M0)               r27.0<1>:d    0:w                               {Compacted}
(W)     mul (1|M0)               acc0.0<1>:d   r27.0<0;1,0>:d    r5.18<0;1,0>:uw  {I@1}
(W)     macl (1|M0)              r6.0<1>:d     r27.0<0;1,0>:d    r5.9<0;1,0>:d    {Compacted}
(W)     shl (1|M0)               r4.4<1>:q     r27.0<0;1,0>:ud   2:w              
(W)     shl (1|M0)               r5.5<1>:q     r6.0<0;1,0>:d     2:w               {I@2}
        add (16|M0)              r7.0<1>:q     r56.0<1;1,0>:q    r4.4<0;1,0>:q    {Compacted,I@2}
        add (16|M16)             r9.0<1>:q     r58.0<1;1,0>:q    r4.4<0;1,0>:q    {Compacted}
        add (16|M0)              r14.0<1>:q    r52.0<1;1,0>:q    r5.5<0;1,0>:q    {Compacted,I@3}
        add (16|M16)             r16.0<1>:q    r54.0<1;1,0>:q    r5.5<0;1,0>:q    {Compacted}
        send.ugm (32|M0)         r12      r7  null:0  0x0            0x08200580           {I@3,$4} // wr:4+0, rd:2; load.ugm.d32.a64
        send.ugm (32|M0)         r18      r14  null:0  0x0            0x08200580           {I@1,$5} // wr:4+0, rd:2; load.ugm.d32.a64
(W)     add (1|M0)               r27.0<1>:d    r27.0<0;1,0>:d    1:w               {Compacted}
(W)     cmp (32|M0)   (lt)f1.0   null<1>:d     r27.0<0;1,0>:d    r5.8<0;1,0>:d    {I@1}
        sync.allwr                           ($4,$5)                
        mad (32|M0)              r38.0<1>:f    r38.0<1;0>:f      r18.0<1;0>:f      r12.0<1>:f       {Compacted,$3.dst}
(W&f1.0) jmpi                                -168                                
        join (32|M0)                         1008                                
        cmp (32|M0)   (ge)f2.0   null<1>:d     r32.0<1;1,0>:d    r5.6<0;1,0>:d   
(~f2.0) cmp (32|M0)   (lt)f2.0   null<1>:d     r32.0<1;1,0>:d    0:w              
(f2.0)  goto (32|M0)                         432                  432                
(~f0.0) goto (32|M0)                         416                  416                
        add (32|M0)              r6.0<1>:d     r32.0<1;1,0>:d    r40.0<1;1,0>:d   {Compacted}
(W)     mul (16|M0)              acc0.0<1>:d   r6.0<1;1,0>:d     r5.16<0;1,0>:uw  {I@1}
        macl (16|M0)             r8.0<1>:d     r6.0<1;1,0>:d     r5.8<0;1,0>:d    {Compacted}
(W)     mul (16|M16)             acc0.0<1>:d   r7.0<1;1,0>:d     r5.16<0;1,0>:uw 
        macl (16|M16)            r9.0<1>:d     r7.0<1;1,0>:d     r5.8<0;1,0>:d    {Compacted}
(W)     mul (1|M0)               acc0.0<1>:d   r5.8<0;1,0>:d     r5.18<0;1,0>:uw 
        mov (16|M0)              r10.0<2>:ud   r8.0<1;1,0>:ud                   {Compacted,I@4}
        mov (16|M16)             r14.0<2>:ud   r9.0<1;1,0>:ud                   {Compacted,I@3}
        sync.nop                             null                             {Compacted,F@1}
(W)     macl (1|M0)              r18.0<1>:d    r5.8<0;1,0>:d     r5.9<0;1,0>:d    {$3.src}
        shl (16|M0)              r12.0<1>:q    r10.0<2;1,0>:d    2:w               {I@3}
        shl (16|M16)             r16.0<1>:q    r14.0<2;1,0>:d    2:w               {I@3}
(W)     shl (1|M0)               r4.4<1>:q     r18.0<0;1,0>:d    2:w               {I@3}
        add (16|M0)              r60.0<1>:q    r12.0<1;1,0>:q    r4.3<0;1,0>:q    {Compacted,I@3}
        add (16|M16)             r62.0<1>:q    r16.0<1;1,0>:q    r4.3<0;1,0>:q    {Compacted,I@3}
        add (16|M0)              r64.0<1>:q    r52.0<1;1,0>:q    r4.4<0;1,0>:q    {Compacted,I@3}
        add (16|M16)             r66.0<1>:q    r54.0<1;1,0>:q    r4.4<0;1,0>:q    {Compacted}
(W)     mov (1|M0)               r27.1<1>:d    0:w                               {Compacted}
(W)     mul (1|M0)               acc0.0<1>:d   r27.1<0;1,0>:d    r5.18<0;1,0>:uw  {I@1}
(W)     macl (1|M0)              r6.0<1>:d     r27.1<0;1,0>:d    r5.9<0;1,0>:d    {Compacted}
(W)     shl (1|M0)               r4.4<1>:q     r27.1<0;1,0>:ud   2:w              
(W)     shl (1|M0)               r5.5<1>:q     r6.0<0;1,0>:d     2:w               {I@2}
        add (16|M0)              r7.0<1>:q     r60.0<1;1,0>:q    r4.4<0;1,0>:q    {Compacted,I@2}
        add (16|M16)             r9.0<1>:q     r62.0<1;1,0>:q    r4.4<0;1,0>:q    {Compacted}
        add (16|M0)              r14.0<1>:q    r64.0<1;1,0>:q    r5.5<0;1,0>:q    {Compacted,I@3}
        add (16|M16)             r16.0<1>:q    r66.0<1;1,0>:q    r5.5<0;1,0>:q    {Compacted}
        send.ugm (32|M0)         r12      r7  null:0  0x0            0x08200580           {I@3,$6} // wr:4+0, rd:2; load.ugm.d32.a64
        send.ugm (32|M0)         r18      r14  null:0  0x0            0x08200580           {I@1,$7} // wr:4+0, rd:2; load.ugm.d32.a64
(W)     add (1|M0)               r27.1<1>:d    r27.1<0;1,0>:d    1:w              
(W)     cmp (32|M0)   (lt)f3.0   null<1>:d     r27.1<0;1,0>:d    r5.8<0;1,0>:d    {I@1}
        sync.allwr                           ($6,$7)                
        mad (32|M0)              r38.0<1>:f    r38.0<1;0>:f      r18.0<1;0>:f      r12.0<1>:f       {$3.dst}
(W&f3.0) jmpi                                -184                                
        join (32|M0)                         528                                
        add3 (32|M0)             r42.0<1>:d    r30.0<1;0>:d      r4.1<0;0>:d       2:w              
        cmp (32|M0)   (gt)f1.0   null<1>:d     r42.0<1;1,0>:d    r5.6<0;1,0>:d    {I@1}
(~f1.0) cmp (32|M0)   (lt)f1.0   null<1>:d     r32.0<1;1,0>:d    -1:w              
(f1.0)  goto (32|M0)                         464                  464                
(~f0.0) goto (32|M0)                         448                  448                
        add3 (32|M0)             r6.0<1>:d     r42.0<1;0>:d      r40.0<1;0>:d      -1:w              
(W)     mul (16|M0)              acc0.0<1>:d   r6.0<1;1,0>:d     r5.16<0;1,0>:uw  {I@1}
(W)     shl (1|M0)               r4.8<1>:d     r5.8<0;1,0>:d     1:w              
        macl (16|M0)             r8.0<1>:d     r6.0<1;1,0>:d     r5.8<0;1,0>:d   
(W)     mul (16|M16)             acc0.0<1>:d   r7.0<1;1,0>:d     r5.16<0;1,0>:uw 
        macl (16|M16)            r9.0<1>:d     r7.0<1;1,0>:d     r5.8<0;1,0>:d    {Compacted}
(W)     mul (1|M0)               acc0.0<1>:d   r4.8<0;1,0>:d     r5.18<0;1,0>:uw  {I@4}
        mov (16|M0)              r10.0<2>:ud   r8.0<1;1,0>:ud                   {Compacted,I@4}
        mov (16|M16)             r14.0<2>:ud   r9.0<1;1,0>:ud                   {Compacted,I@3}
        sync.nop                             null                             {Compacted,F@1}
(W)     macl (1|M0)              r18.0<1>:d    r4.8<0;1,0>:d     r5.9<0;1,0>:d    {Compacted,$3.src}
        shl (16|M0)              r12.0<1>:q    r10.0<2;1,0>:d    2:w               {I@3}
        shl (16|M16)             r16.0<1>:q    r14.0<2;1,0>:d    2:w               {I@3}
(W)     shl (1|M0)               r5.5<1>:q     r18.0<0;1,0>:d    2:w               {I@3}
        add (16|M0)              r68.0<1>:q    r12.0<1;1,0>:q    r4.3<0;1,0>:q    {Compacted,I@3}
        add (16|M16)             r70.0<1>:q    r16.0<1;1,0>:q    r4.3<0;1,0>:q    {Compacted,I@3}
        add (16|M0)              r72.0<1>:q    r52.0<1;1,0>:q    r5.5<0;1,0>:q    {Compacted,I@3}
        add (16|M16)             r74.0<1>:q    r54.0<1;1,0>:q    r5.5<0;1,0>:q    {Compacted}
(W)     mov (1|M0)               r27.2<1>:d    0:w                               {Compacted}
(W)     mul (1|M0)               acc0.0<1>:d   r27.2<0;1,0>:d    r5.18<0;1,0>:uw  {I@1}
(W)     macl (1|M0)              r6.0<1>:d     r27.2<0;1,0>:d    r5.9<0;1,0>:d   
(W)     shl (1|M0)               r4.4<1>:q     r27.2<0;1,0>:ud   2:w              
(W)     shl (1|M0)               r5.5<1>:q     r6.0<0;1,0>:d     2:w               {I@2}
        add (16|M0)              r7.0<1>:q     r68.0<1;1,0>:q    r4.4<0;1,0>:q    {Compacted,I@2}
        add (16|M16)             r9.0<1>:q     r70.0<1;1,0>:q    r4.4<0;1,0>:q    {Compacted}
        add (16|M0)              r14.0<1>:q    r72.0<1;1,0>:q    r5.5<0;1,0>:q    {Compacted,I@3}
        add (16|M16)             r16.0<1>:q    r74.0<1;1,0>:q    r5.5<0;1,0>:q    {Compacted}
        send.ugm (32|M0)         r12      r7  null:0  0x0            0x08200580           {I@3,$8} // wr:4+0, rd:2; load.ugm.d32.a64
        send.ugm (32|M0)         r18      r14  null:0  0x0            0x08200580           {I@1,$9} // wr:4+0, rd:2; load.ugm.d32.a64
(W)     add (1|M0)               r27.2<1>:d    r27.2<0;1,0>:d    1:w              
(W)     cmp (32|M0)   (lt)f2.0   null<1>:d     r27.2<0;1,0>:d    r5.8<0;1,0>:d    {I@1}
        sync.allwr                           ($8,$9)                
        mad (32|M0)              r38.0<1>:f    r38.0<1;0>:f      r18.0<1;0>:f      r12.0<1>:f       {$3.dst}
(W&f2.0) jmpi                                -192                                
        join (32|M0)                         3560                                
        cmp (32|M0)   (ge)f3.0   null<1>:d     r36.0<1;1,0>:d    r5.7<0;1,0>:d   
(~f3.0) cmp (32|M0)   (lt)f3.0   null<1>:d     r36.0<1;1,0>:d    0:w              
(f3.0)  goto (32|M0)                         1600                  1600                
        cmp (32|M0)   (gt)f2.0   null<1>:d     r32.0<1;1,0>:d    r5.6<0;1,0>:d   
(~f2.0) cmp (32|M0)   (lt)f2.0   null<1>:d     r32.0<1;1,0>:d    1:w              
(W)     mul (16|M0)              acc0.0<1>:d   r36.0<1;1,0>:d    r5.12<0;1,0>:uw 
        macl (16|M0)             r44.0<1>:d    r36.0<1;1,0>:d    r5.6<0;1,0>:d    {Compacted}
(W)     mul (16|M16)             acc0.0<1>:d   r37.0<1;1,0>:d    r5.12<0;1,0>:uw 
        macl (16|M16)            r45.0<1>:d    r37.0<1;1,0>:d    r5.6<0;1,0>:d    {Compacted}
(f2.0)  goto (32|M0)                         464                  464                
(~f0.0) goto (32|M0)                         448                  448                
        add3 (32|M0)             r6.0<1>:d     r32.0<1;0>:d      r44.0<1;0>:d      -1:w               {I@3}
(W)     mul (16|M0)              acc0.0<1>:d   r6.0<1;1,0>:d     r5.16<0;1,0>:uw  {I@1}
(W)     mul (1|M0)               r4.8<1>:d     r5.8<0;1,0>:d     3:w              
        macl (16|M0)             r8.0<1>:d     r6.0<1;1,0>:d     r5.8<0;1,0>:d    {Compacted}
(W)     mul (16|M16)             acc0.0<1>:d   r7.0<1;1,0>:d     r5.16<0;1,0>:uw 
        macl (16|M16)            r9.0<1>:d     r7.0<1;1,0>:d     r5.8<0;1,0>:d    {Compacted}
(W)     mul (1|M0)               acc0.0<1>:d   r4.8<0;1,0>:d     r5.18<0;1,0>:uw  {I@4}
        mov (16|M0)              r10.0<2>:ud   r8.0<1;1,0>:ud                   {Compacted,I@4}
        mov (16|M16)             r14.0<2>:ud   r9.0<1;1,0>:ud                   {Compacted,I@3}
        sync.nop                             null                             {Compacted,F@1}
(W)     macl (1|M0)              r18.0<1>:d    r4.8<0;1,0>:d     r5.9<0;1,0>:d    {Compacted,$3.src}
        shl (16|M0)              r12.0<1>:q    r10.0<2;1,0>:d    2:w               {I@3}
        shl (16|M16)             r16.0<1>:q    r14.0<2;1,0>:d    2:w               {I@3}
(W)     shl (1|M0)               r5.5<1>:q     r18.0<0;1,0>:d    2:w               {I@3}
        add (16|M0)              r76.0<1>:q    r12.0<1;1,0>:q    r4.3<0;1,0>:q    {Compacted,I@3}
        add (16|M16)             r78.0<1>:q    r16.0<1;1,0>:q    r4.3<0;1,0>:q    {Compacted,I@3}
        add (16|M0)              r80.0<1>:q    r52.0<1;1,0>:q    r5.5<0;1,0>:q    {Compacted,I@3}
        add (16|M16)             r82.0<1>:q    r54.0<1;1,0>:q    r5.5<0;1,0>:q    {Compacted}
(W)     mov (1|M0)               r27.3<1>:d    0:w                              
(W)     mul (1|M0)               acc0.0<1>:d   r27.3<0;1,0>:d    r5.18<0;1,0>:uw  {I@1}
(W)     macl (1|M0)              r6.0<1>:d     r27.3<0;1,0>:d    r5.9<0;1,0>:d    {Compacted}
(W)     shl (1|M0)               r4.4<1>:q     r27.3<0;1,0>:ud   2:w              
(W)     shl (1|M0)               r5.5<1>:q     r6.0<0;1,0>:d     2:w               {I@2}
        add (16|M0)              r7.0<1>:q     r76.0<1;1,0>:q    r4.4<0;1,0>:q    {Compacted,I@2}
        add (16|M16)             r9.0<1>:q     r78.0<1;1,0>:q    r4.4<0;1,0>:q    {Compacted}
        add (16|M0)              r14.0<1>:q    r80.0<1;1,0>:q    r5.5<0;1,0>:q    {Compacted,I@3}
        add (16|M16)             r16.0<1>:q    r82.0<1;1,0>:q    r5.5<0;1,0>:q   
        send.ugm (32|M0)         r12      r7  null:0  0x0            0x08200580           {I@3,$10} // wr:4+0, rd:2; load.ugm.d32.a64
        send.ugm (32|M0)         r18      r14  null:0  0x0            0x08200580           {I@1,$11} // wr:4+0, rd:2; load.ugm.d32.a64
(W)     add (1|M0)               r27.3<1>:d    r27.3<0;1,0>:d    1:w              
(W)     cmp (32|M0)   (lt)f1.0   null<1>:d     r27.3<0;1,0>:d    r5.8<0;1,0>:d    {I@1}
        sync.allwr                           ($10,$11)                
        mad (32|M0)              r38.0<1>:f    r38.0<1;0>:f      r18.0<1;0>:f      r12.0<1>:f       {$3.dst}
(W&f1.0) jmpi                                -192                                
        join (32|M0)                         1040                                
        cmp (32|M0)   (ge)f1.0   null<1>:d     r32.0<1;1,0>:d    r5.6<0;1,0>:d   
(~f1.0) cmp (32|M0)   (lt)f1.0   null<1>:d     r32.0<1;1,0>:d    0:w              
(f1.0)  goto (32|M0)                         464                  464                
(~f0.0) goto (32|M0)                         448                  448                
        add (32|M0)              r6.0<1>:d     r32.0<1;1,0>:d    r44.0<1;1,0>:d  
(W)     mul (16|M0)              acc0.0<1>:d   r6.0<1;1,0>:d     r5.16<0;1,0>:uw  {I@1}
(W)     shl (1|M0)               r4.8<1>:d     r5.8<0;1,0>:d     2:w              
        macl (16|M0)             r8.0<1>:d     r6.0<1;1,0>:d     r5.8<0;1,0>:d    {Compacted}
(W)     mul (16|M16)             acc0.0<1>:d   r7.0<1;1,0>:d     r5.16<0;1,0>:uw 
        macl (16|M16)            r9.0<1>:d     r7.0<1;1,0>:d     r5.8<0;1,0>:d    {Compacted}
(W)     mul (1|M0)               acc0.0<1>:d   r4.8<0;1,0>:d     r5.18<0;1,0>:uw  {I@4}
        mov (16|M0)              r10.0<2>:ud   r8.0<1;1,0>:ud                   {Compacted,I@4}
        mov (16|M16)             r14.0<2>:ud   r9.0<1;1,0>:ud                   {Compacted,I@3}
        sync.nop                             null                             {Compacted,F@1}
(W)     macl (1|M0)              r18.0<1>:d    r4.8<0;1,0>:d     r5.9<0;1,0>:d    {Compacted,$3.src}
        shl (16|M0)              r12.0<1>:q    r10.0<2;1,0>:d    2:w               {I@3}
        shl (16|M16)             r16.0<1>:q    r14.0<2;1,0>:d    2:w               {I@3}
(W)     shl (1|M0)               r5.5<1>:q     r18.0<0;1,0>:d    2:w               {I@3}
        add (16|M0)              r84.0<1>:q    r12.0<1;1,0>:q    r4.3<0;1,0>:q    {Compacted,I@3}
        add (16|M16)             r86.0<1>:q    r16.0<1;1,0>:q    r4.3<0;1,0>:q    {Compacted,I@3}
        add (16|M0)              r88.0<1>:q    r52.0<1;1,0>:q    r5.5<0;1,0>:q    {Compacted,I@3}
        add (16|M16)             r90.0<1>:q    r54.0<1;1,0>:q    r5.5<0;1,0>:q    {Compacted}
(W)     mov (1|M0)               r27.4<1>:d    0:w                              
(W)     mul (1|M0)               acc0.0<1>:d   r27.4<0;1,0>:d    r5.18<0;1,0>:uw  {I@1}
(W)     macl (1|M0)              r6.0<1>:d     r27.4<0;1,0>:d    r5.9<0;1,0>:d    {Compacted}
(W)     shl (1|M0)               r4.4<1>:q     r27.4<0;1,0>:ud   2:w              
(W)     shl (1|M0)               r5.5<1>:q     r6.0<0;1,0>:d     2:w               {I@2}
        add (16|M0)              r7.0<1>:q     r84.0<1;1,0>:q    r4.4<0;1,0>:q    {Compacted,I@2}
        add (16|M16)             r9.0<1>:q     r86.0<1;1,0>:q    r4.4<0;1,0>:q    {Compacted}
        add (16|M0)              r14.0<1>:q    r88.0<1;1,0>:q    r5.5<0;1,0>:q    {Compacted,I@3}
        add (16|M16)             r16.0<1>:q    r90.0<1;1,0>:q    r5.5<0;1,0>:q   
        send.ugm (32|M0)         r12      r7  null:0  0x0            0x08200580           {I@3,$12} // wr:4+0, rd:2; load.ugm.d32.a64
        send.ugm (32|M0)         r18      r14  null:0  0x0            0x08200580           {I@1,$13} // wr:4+0, rd:2; load.ugm.d32.a64
(W)     add (1|M0)               r27.4<1>:d    r27.4<0;1,0>:d    1:w              
(W)     cmp (32|M0)   (lt)f3.0   null<1>:d     r27.4<0;1,0>:d    r5.8<0;1,0>:d    {I@1}
        sync.allwr                           ($12,$13)                
        mad (32|M0)              r38.0<1>:f    r38.0<1;0>:f      r18.0<1;0>:f      r12.0<1>:f       {$3.dst}
(W&f3.0) jmpi                                -192                                
        join (32|M0)                         528                                
        add3 (32|M0)             r46.0<1>:d    r30.0<1;0>:d      r4.1<0;0>:d       2:w              
        cmp (32|M0)   (gt)f3.0   null<1>:d     r46.0<1;1,0>:d    r5.6<0;1,0>:d    {I@1}
(~f3.0) cmp (32|M0)   (lt)f3.0   null<1>:d     r32.0<1;1,0>:d    -1:w              
(f3.0)  goto (32|M0)                         464                  464                
(~f0.0) goto (32|M0)                         448                  448                
        add3 (32|M0)             r6.0<1>:d     r46.0<1;0>:d      r44.0<1;0>:d      -1:w              
(W)     mul (16|M0)              acc0.0<1>:d   r6.0<1;1,0>:d     r5.16<0;1,0>:uw  {I@1}
(W)     mul (1|M0)               r4.8<1>:d     r5.8<0;1,0>:d     5:w              
        macl (16|M0)             r8.0<1>:d     r6.0<1;1,0>:d     r5.8<0;1,0>:d    {Compacted}
(W)     mul (16|M16)             acc0.0<1>:d   r7.0<1;1,0>:d     r5.16<0;1,0>:uw 
        macl (16|M16)            r9.0<1>:d     r7.0<1;1,0>:d     r5.8<0;1,0>:d    {Compacted}
(W)     mul (1|M0)               acc0.0<1>:d   r4.8<0;1,0>:d     r5.18<0;1,0>:uw  {I@4}
        mov (16|M0)              r10.0<2>:ud   r8.0<1;1,0>:ud                   {Compacted,I@4}
        mov (16|M16)             r14.0<2>:ud   r9.0<1;1,0>:ud                   {Compacted,I@3}
        sync.nop                             null                             {Compacted,F@1}
(W)     macl (1|M0)              r18.0<1>:d    r4.8<0;1,0>:d     r5.9<0;1,0>:d    {Compacted,$3.src}
        shl (16|M0)              r12.0<1>:q    r10.0<2;1,0>:d    2:w               {I@3}
        shl (16|M16)             r16.0<1>:q    r14.0<2;1,0>:d    2:w               {I@3}
(W)     shl (1|M0)               r5.5<1>:q     r18.0<0;1,0>:d    2:w               {I@3}
        add (16|M0)              r92.0<1>:q    r12.0<1;1,0>:q    r4.3<0;1,0>:q    {Compacted,I@3}
        add (16|M16)             r94.0<1>:q    r16.0<1;1,0>:q    r4.3<0;1,0>:q    {Compacted,I@3}
        add (16|M0)              r96.0<1>:q    r52.0<1;1,0>:q    r5.5<0;1,0>:q    {Compacted,I@3}
        add (16|M16)             r98.0<1>:q    r54.0<1;1,0>:q    r5.5<0;1,0>:q    {Compacted}
(W)     mov (1|M0)               r27.5<1>:d    0:w                              
(W)     mul (1|M0)               acc0.0<1>:d   r27.5<0;1,0>:d    r5.18<0;1,0>:uw  {I@1}
(W)     macl (1|M0)              r6.0<1>:d     r27.5<0;1,0>:d    r5.9<0;1,0>:d   
(W)     shl (1|M0)               r4.4<1>:q     r27.5<0;1,0>:ud   2:w              
(W)     shl (1|M0)               r5.5<1>:q     r6.0<0;1,0>:d     2:w               {I@2}
        add (16|M0)              r7.0<1>:q     r92.0<1;1,0>:q    r4.4<0;1,0>:q    {Compacted,I@2}
        add (16|M16)             r9.0<1>:q     r94.0<1;1,0>:q    r4.4<0;1,0>:q    {Compacted}
        add (16|M0)              r14.0<1>:q    r96.0<1;1,0>:q    r5.5<0;1,0>:q    {Compacted,I@3}
        add (16|M16)             r16.0<1>:q    r98.0<1;1,0>:q    r5.5<0;1,0>:q    {Compacted}
        send.ugm (32|M0)         r12      r7  null:0  0x0            0x08200580           {I@3,$14} // wr:4+0, rd:2; load.ugm.d32.a64
        send.ugm (32|M0)         r18      r14  null:0  0x0            0x08200580           {I@1,$15} // wr:4+0, rd:2; load.ugm.d32.a64
(W)     add (1|M0)               r27.5<1>:d    r27.5<0;1,0>:d    1:w              
(W)     cmp (32|M0)   (lt)f2.0   null<1>:d     r27.5<0;1,0>:d    r5.8<0;1,0>:d    {I@1}
        sync.allwr                           ($14,$15)                
        mad (32|M0)              r38.0<1>:f    r38.0<1;0>:f      r18.0<1;0>:f      r12.0<1>:f       {$3.dst}
(W&f2.0) jmpi                                -192                                
        join (32|M0)                         1912                                
        add3 (32|M0)             r6.0<1>:d     r34.0<1;0>:d      r4.2<0;0>:d       2:w              
        cmp (32|M0)   (gt)f2.0   null<1>:d     r6.0<1;1,0>:d     r5.7<0;1,0>:d    {I@1}
(~f2.0) cmp (32|M0)   (lt)f2.0   null<1>:d     r36.0<1;1,0>:d    -1:w              
(f2.0)  goto (32|M0)                         1632                  1632                
        cmp (32|M0)   (gt)f1.0   null<1>:d     r32.0<1;1,0>:d    r5.6<0;1,0>:d   
        add3 (32|M0)             r6.0<1>:d     r34.0<1;0>:d      r4.2<0;0>:d       1:w              
(~f1.0) cmp (32|M0)   (lt)f1.0   null<1>:d     r32.0<1;1,0>:d    1:w              
(W)     mul (16|M0)              acc0.0<1>:d   r6.0<1;1,0>:d     r5.12<0;1,0>:uw  {I@2}
        macl (16|M0)             r48.0<1>:d    r6.0<1;1,0>:d     r5.6<0;1,0>:d   
(W)     mul (16|M16)             acc0.0<1>:d   r7.0<1;1,0>:d     r5.12<0;1,0>:uw 
        macl (16|M16)            r49.0<1>:d    r7.0<1;1,0>:d     r5.6<0;1,0>:d   
(f1.0)  goto (32|M0)                         464                  464                
(~f0.0) goto (32|M0)                         448                  448                
        add3 (32|M0)             r6.0<1>:d     r32.0<1;0>:d      r48.0<1;0>:d      -1:w               {I@3}
(W)     mul (16|M0)              acc0.0<1>:d   r6.0<1;1,0>:d     r5.16<0;1,0>:uw  {I@1}
(W)     mul (1|M0)               r4.8<1>:d     r5.8<0;1,0>:d     6:w              
        macl (16|M0)             r8.0<1>:d     r6.0<1;1,0>:d     r5.8<0;1,0>:d   
(W)     mul (16|M16)             acc0.0<1>:d   r7.0<1;1,0>:d     r5.16<0;1,0>:uw 
        macl (16|M16)            r9.0<1>:d     r7.0<1;1,0>:d     r5.8<0;1,0>:d    {Compacted}
(W)     mul (1|M0)               acc0.0<1>:d   r4.8<0;1,0>:d     r5.18<0;1,0>:uw  {I@4}
        mov (16|M0)              r10.0<2>:ud   r8.0<1;1,0>:ud                   {Compacted,I@4}
        mov (16|M16)             r14.0<2>:ud   r9.0<1;1,0>:ud                   {Compacted,I@3}
        sync.nop                             null                             {Compacted,F@1}
(W)     macl (1|M0)              r18.0<1>:d    r4.8<0;1,0>:d     r5.9<0;1,0>:d    {Compacted,$3.src}
        shl (16|M0)              r12.0<1>:q    r10.0<2;1,0>:d    2:w               {I@3}
        shl (16|M16)             r16.0<1>:q    r14.0<2;1,0>:d    2:w               {I@3}
(W)     shl (1|M0)               r5.5<1>:q     r18.0<0;1,0>:d    2:w               {I@3}
        add (16|M0)              r100.0<1>:q   r12.0<1;1,0>:q    r4.3<0;1,0>:q    {Compacted,I@3}
        add (16|M16)             r102.0<1>:q   r16.0<1;1,0>:q    r4.3<0;1,0>:q    {Compacted,I@3}
        add (16|M0)              r104.0<1>:q   r52.0<1;1,0>:q    r5.5<0;1,0>:q    {Compacted,I@3}
        add (16|M16)             r106.0<1>:q   r54.0<1;1,0>:q    r5.5<0;1,0>:q    {Compacted}
(W)     mov (1|M0)               r27.6<1>:d    0:w                              
(W)     mul (1|M0)               acc0.0<1>:d   r27.6<0;1,0>:d    r5.18<0;1,0>:uw  {I@1}
(W)     macl (1|M0)              r6.0<1>:d     r27.6<0;1,0>:d    r5.9<0;1,0>:d    {Compacted}
(W)     shl (1|M0)               r4.4<1>:q     r27.6<0;1,0>:ud   2:w              
(W)     shl (1|M0)               r5.5<1>:q     r6.0<0;1,0>:d     2:w               {I@2}
        add (16|M0)              r7.0<1>:q     r100.0<1;1,0>:q   r4.4<0;1,0>:q    {Compacted,I@2}
        add (16|M16)             r9.0<1>:q     r102.0<1;1,0>:q   r4.4<0;1,0>:q    {Compacted}
        add (16|M0)              r14.0<1>:q    r104.0<1;1,0>:q   r5.5<0;1,0>:q    {Compacted,I@3}
        add (16|M16)             r16.0<1>:q    r106.0<1;1,0>:q   r5.5<0;1,0>:q    {Compacted}
        send.ugm (32|M0)         r12      r7  null:0  0x0            0x08200580           {I@3,$0} // wr:4+0, rd:2; load.ugm.d32.a64
        send.ugm (32|M0)         r18      r14  null:0  0x0            0x08200580           {I@1,$1} // wr:4+0, rd:2; load.ugm.d32.a64
(W)     add (1|M0)               r27.6<1>:d    r27.6<0;1,0>:d    1:w              
(W)     cmp (32|M0)   (lt)f1.0   null<1>:d     r27.6<0;1,0>:d    r5.8<0;1,0>:d    {I@1}
        sync.allwr                           ($0,$1)                
        mad (32|M0)              r38.0<1>:f    r38.0<1;0>:f      r18.0<1;0>:f      r12.0<1>:f       {$3.dst}
(W&f1.0) jmpi                                -184                                
        join (32|M0)                         1040                                
        cmp (32|M0)   (ge)f3.0   null<1>:d     r32.0<1;1,0>:d    r5.6<0;1,0>:d   
(~f3.0) cmp (32|M0)   (lt)f3.0   null<1>:d     r32.0<1;1,0>:d    0:w              
(f3.0)  goto (32|M0)                         464                  464                
(~f0.0) goto (32|M0)                         448                  448                
        add (32|M0)              r6.0<1>:d     r32.0<1;1,0>:d    r48.0<1;1,0>:d   {Compacted}
(W)     mul (16|M0)              acc0.0<1>:d   r6.0<1;1,0>:d     r5.16<0;1,0>:uw  {I@1}
(W)     mul (1|M0)               r4.8<1>:d     r5.8<0;1,0>:d     7:w              
        macl (16|M0)             r8.0<1>:d     r6.0<1;1,0>:d     r5.8<0;1,0>:d    {Compacted}
(W)     mul (16|M16)             acc0.0<1>:d   r7.0<1;1,0>:d     r5.16<0;1,0>:uw 
        macl (16|M16)            r9.0<1>:d     r7.0<1;1,0>:d     r5.8<0;1,0>:d    {Compacted}
(W)     mul (1|M0)               acc0.0<1>:d   r4.8<0;1,0>:d     r5.18<0;1,0>:uw  {I@4}
        mov (16|M0)              r10.0<2>:ud   r8.0<1;1,0>:ud                   {Compacted,I@4}
        mov (16|M16)             r14.0<2>:ud   r9.0<1;1,0>:ud                   {Compacted,I@3}
        sync.nop                             null                             {Compacted,F@1}
(W)     macl (1|M0)              r18.0<1>:d    r4.8<0;1,0>:d     r5.9<0;1,0>:d    {$3.src}
        shl (16|M0)              r12.0<1>:q    r10.0<2;1,0>:d    2:w               {I@3}
        shl (16|M16)             r16.0<1>:q    r14.0<2;1,0>:d    2:w               {I@3}
(W)     shl (1|M0)               r5.5<1>:q     r18.0<0;1,0>:d    2:w               {I@3}
        add (16|M0)              r108.0<1>:q   r12.0<1;1,0>:q    r4.3<0;1,0>:q    {Compacted,I@3}
        add (16|M16)             r110.0<1>:q   r16.0<1;1,0>:q    r4.3<0;1,0>:q    {Compacted,I@3}
        add (16|M0)              r112.0<1>:q   r52.0<1;1,0>:q    r5.5<0;1,0>:q    {Compacted,I@3}
        add (16|M16)             r114.0<1>:q   r54.0<1;1,0>:q    r5.5<0;1,0>:q    {Compacted}
(W)     mov (1|M0)               r27.7<1>:d    0:w                              
(W)     mul (1|M0)               acc0.0<1>:d   r27.7<0;1,0>:d    r5.18<0;1,0>:uw  {I@1}
(W)     macl (1|M0)              r6.0<1>:d     r27.7<0;1,0>:d    r5.9<0;1,0>:d   
(W)     shl (1|M0)               r4.4<1>:q     r27.7<0;1,0>:ud   2:w              
(W)     shl (1|M0)               r5.5<1>:q     r6.0<0;1,0>:d     2:w               {I@2}
        add (16|M0)              r7.0<1>:q     r108.0<1;1,0>:q   r4.4<0;1,0>:q    {Compacted,I@2}
        add (16|M16)             r9.0<1>:q     r110.0<1;1,0>:q   r4.4<0;1,0>:q    {Compacted}
        add (16|M0)              r14.0<1>:q    r112.0<1;1,0>:q   r5.5<0;1,0>:q    {Compacted,I@3}
        add (16|M16)             r16.0<1>:q    r114.0<1;1,0>:q   r5.5<0;1,0>:q    {Compacted}
        send.ugm (32|M0)         r12      r7  null:0  0x0            0x08200580           {I@3,$2} // wr:4+0, rd:2; load.ugm.d32.a64
        send.ugm (32|M0)         r18      r14  null:0  0x0            0x08200580           {I@1,$4} // wr:4+0, rd:2; load.ugm.d32.a64
(W)     add (1|M0)               r27.7<1>:d    r27.7<0;1,0>:d    1:w              
(W)     cmp (32|M0)   (lt)f3.0   null<1>:d     r27.7<0;1,0>:d    r5.8<0;1,0>:d    {I@1}
        sync.allwr                           ($2,$4)                
        mad (32|M0)              r38.0<1>:f    r38.0<1;0>:f      r18.0<1;0>:f      r12.0<1>:f       {$3.dst}
(W&f3.0) jmpi                                -192                                
        join (32|M0)                         528                                
        add3 (32|M0)             r50.0<1>:d    r30.0<1;0>:d      r4.1<0;0>:d       2:w              
        cmp (32|M0)   (gt)f2.0   null<1>:d     r50.0<1;1,0>:d    r5.6<0;1,0>:d    {I@1}
(~f2.0) cmp (32|M0)   (lt)f2.0   null<1>:d     r32.0<1;1,0>:d    -1:w              
(f2.0)  goto (32|M0)                         464                  464                
(~f0.0) goto (32|M0)                         448                  448                
        add3 (32|M0)             r6.0<1>:d     r50.0<1;0>:d      r48.0<1;0>:d      -1:w              
(W)     mul (16|M0)              acc0.0<1>:d   r6.0<1;1,0>:d     r5.16<0;1,0>:uw  {I@1}
(W)     shl (1|M0)               r4.8<1>:d     r5.8<0;1,0>:d     3:w              
        macl (16|M0)             r8.0<1>:d     r6.0<1;1,0>:d     r5.8<0;1,0>:d    {Compacted}
(W)     mul (16|M16)             acc0.0<1>:d   r7.0<1;1,0>:d     r5.16<0;1,0>:uw 
        macl (16|M16)            r9.0<1>:d     r7.0<1;1,0>:d     r5.8<0;1,0>:d    {Compacted}
(W)     mul (1|M0)               acc0.0<1>:d   r4.8<0;1,0>:d     r5.18<0;1,0>:uw  {I@4}
        mov (16|M0)              r10.0<2>:ud   r8.0<1;1,0>:ud                   {Compacted,I@4}
        mov (16|M16)             r14.0<2>:ud   r9.0<1;1,0>:ud                   {Compacted,I@3}
        sync.nop                             null                             {Compacted,F@1}
(W)     macl (1|M0)              r18.0<1>:d    r4.8<0;1,0>:d     r5.9<0;1,0>:d    {Compacted,$3.src}
        shl (16|M0)              r12.0<1>:q    r10.0<2;1,0>:d    2:w               {I@3}
        shl (16|M16)             r16.0<1>:q    r14.0<2;1,0>:d    2:w               {I@3}
(W)     shl (1|M0)               r5.5<1>:q     r18.0<0;1,0>:d    2:w               {I@3}
        add (16|M0)              r116.0<1>:q   r12.0<1;1,0>:q    r4.3<0;1,0>:q    {Compacted,I@3}
        add (16|M16)             r118.0<1>:q   r16.0<1;1,0>:q    r4.3<0;1,0>:q    {Compacted,I@3}
        add (16|M0)              r120.0<1>:q   r52.0<1;1,0>:q    r5.5<0;1,0>:q    {Compacted,I@3}
        add (16|M16)             r122.0<1>:q   r54.0<1;1,0>:q    r5.5<0;1,0>:q    {Compacted}
(W)     mov (1|M0)               r27.8<1>:d    0:w                              
(W)     mul (1|M0)               acc0.0<1>:d   r27.8<0;1,0>:d    r5.18<0;1,0>:uw  {I@1}
(W)     macl (1|M0)              r6.0<1>:d     r27.8<0;1,0>:d    r5.9<0;1,0>:d    {Compacted}
(W)     shl (1|M0)               r4.4<1>:q     r27.8<0;1,0>:ud   2:w              
(W)     shl (1|M0)               r5.5<1>:q     r6.0<0;1,0>:d     2:w               {I@2}
        add (16|M0)              r7.0<1>:q     r116.0<1;1,0>:q   r4.4<0;1,0>:q    {Compacted,I@2}
        add (16|M16)             r9.0<1>:q     r118.0<1;1,0>:q   r4.4<0;1,0>:q    {Compacted}
        add (16|M0)              r14.0<1>:q    r120.0<1;1,0>:q   r5.5<0;1,0>:q    {Compacted,I@3}
        add (16|M16)             r16.0<1>:q    r122.0<1;1,0>:q   r5.5<0;1,0>:q   
        send.ugm (32|M0)         r12      r7  null:0  0x0            0x08200580           {I@3,$5} // wr:4+0, rd:2; load.ugm.d32.a64
        send.ugm (32|M0)         r18      r14  null:0  0x0            0x08200580           {I@1,$6} // wr:4+0, rd:2; load.ugm.d32.a64
(W)     add (1|M0)               r27.8<1>:d    r27.8<0;1,0>:d    1:w              
(W)     cmp (32|M0)   (lt)f2.0   null<1>:d     r27.8<0;1,0>:d    r5.8<0;1,0>:d    {I@1}
        sync.allwr                           ($5,$6)                
        mad (32|M0)              r38.0<1>:f    r38.0<1;0>:f      r18.0<1;0>:f      r12.0<1>:f       {$3.dst}
(W&f2.0) jmpi                                -192                                
        join (32|M0)                         216                                
(W)     mul (16|M0)              acc0.0<1>:d   r36.0<1;1,0>:d    r5.12<0;1,0>:uw 
        macl (16|M0)             r6.0<1>:d     r36.0<1;1,0>:d    r5.6<0;1,0>:d    {Compacted}
(W)     mul (16|M16)             acc0.0<1>:d   r37.0<1;1,0>:d    r5.12<0;1,0>:uw 
        macl (16|M16)            r7.0<1>:d     r37.0<1;1,0>:d    r5.6<0;1,0>:d    {Compacted}
        add (32|M0)              r8.0<1>:d     r6.0<1;1,0>:d     r32.0<1;1,0>:d   {Compacted,I@1}
(W)     mul (16|M0)              acc0.0<1>:d   r8.0<1;1,0>:d     r5.18<0;1,0>:uw  {I@1}
        macl (16|M0)             r10.0<1>:d    r8.0<1;1,0>:d     r5.9<0;1,0>:d    {Compacted}
(W)     mul (16|M16)             acc0.0<1>:d   r9.0<1;1,0>:d     r5.18<0;1,0>:uw 
        macl (16|M16)            r11.0<1>:d    r9.0<1;1,0>:d     r5.9<0;1,0>:d    {Compacted}
        add (32|M0)              r12.0<1>:d    r10.0<1;1,0>:d    r28.0<1;1,0>:d   {Compacted,A@1}
        mov (16|M0)              r14.0<2>:ud   r12.0<1;1,0>:ud                  {Compacted,I@1}
        mov (16|M16)             r18.0<2>:ud   r13.0<1;1,0>:ud                  {Compacted,$3.src}
        shl (16|M0)              r16.0<1>:q    r14.0<2;1,0>:d    2:w               {I@2}
        shl (16|M16)             r20.0<1>:q    r18.0<2;1,0>:d    2:w               {I@2}
        add (16|M0)              r22.0<1>:q    r16.0<1;1,0>:q    r5.2<0;1,0>:q    {Compacted,I@2}
        add (16|M16)             r24.0<1>:q    r20.0<1;1,0>:q    r5.2<0;1,0>:q    {Compacted,I@2}
        sync.nop                             null                             {Compacted,$3.dst}
        send.ugm (32|M0)         null     r22  r38:2  0x0            0x08000584           {I@1,$7} // wr:4+2, rd:0; store.ugm.d32.a64
        join (32|M0)                         16                                
(W)     mov (16|M0)              r127.0<1>:f   r26.0<1;1,0>:f                   {Compacted}
(W)     send.gtwy (1|M0)         null     r127  null:0  0x0            0x02000010           {EOT,F@1,$8} // wr:1+0, rd:0; end of thread
(W)     mov (16|M0)              null<1>:ud    0xC98FA22F:ud                             
(W)     mov (16|M0)              null<1>:ud    0x330C2E64:ud                             
(W)     mov (16|M0)              null<1>:ud    0x0:ud                             
(W)     mov (16|M0)              null<1>:ud    0x7:ud                             
        illegal                
        illegal                
        illegal                
        illegal                
        illegal                
        illegal                
        illegal                
        illegal                
