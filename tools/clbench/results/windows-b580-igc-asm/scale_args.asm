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
(W)     macl (1|M0)              r5.0<1>:d     r2.3<0;1,0>:d     r4.1<0;1,0>:d   
        add3 (32|M0)             r6.0<1>:d     r5.0<0;0>:d       r1.0<1;0>:uw      r2.0<0>:d        {@1,$0.dst}
        cmp (32|M0)   (lt)f2.0   null<1>:d     r6.0<1;1,0>:d     r3.6<0;1,0>:d    {@1,$1.dst}
(~f2.0) goto (32|M0)                         864                  864                
(W)     cmp (32|M0)   (eq)f1.0   null<1>:d     r3.6<0;1,0>:d     0:w              
(W&f1.0) jmpi                                592                                
(W)     mul (16|M0)              acc0.0<1>:d   r6.0<1;1,0>:d     r3.14<0;1,0>:uw 
        macl (16|M0)             r8.0<1>:d     r6.0<1;1,0>:d     r3.7<0;1,0>:d    {Compacted}
(W)     mul (16|M16)             acc0.0<1>:d   r7.0<1;1,0>:d     r3.14<0;1,0>:uw 
        macl (16|M16)            r9.0<1>:d     r7.0<1;1,0>:d     r3.7<0;1,0>:d    {Compacted}
        asr (32|M0)              r11.0<1>:d    r8.0<1;1,0>:d     31:w               {Compacted,I@1}
        add (32|M0)              r13.0<1>:d    r11.0<1;1,0>:d    r8.0<1;1,0>:d    {Compacted,I@1}
        xor (32|M0)              r15.0<1>:d    r13.0<1;1,0>:d    r11.0<1;1,0>:d   {I@1}
(W)     mov (1|M0)               r2.8<1>:d     (abs)r3.6<0;1,0>:d              
(W)     xor (1|M0)               cr0.0<1>:ud   cr0.0<0;1,0>:ud   0x30:uw              {A@1}
(W)     mov (1|M0)               r2.9<1>:f     r2.8<0;1,0>:ud                   {A@1}
(W)     mov (1|M0)               r3.11<1>:f    0xB4C00000:f                              
(W)     math.inv (1|M0)          r2.12<1>:f    r2.9<0;1,0>:f                    {F@2}
        mov (32|M0)              r17.0<1>:f    r15.0<1;1,0>:ud                 
(W)     mad (1|M0)               r2.13<1>:f    r2.12<0;0>:f      r3.11<0;0>:f      r2.12<0>:f       {A@1}
        mov (32|M0)              r21.0<1>:ud   r17.0<1;1,0>:f                   {F@2}
        mul (32|M0)              r19.0<1>:f    r17.0<1;1,0>:f    r2.13<0;1,0>:f   {F@1}
(W)     mov (1|M0)               r2.10<1>:ud   r2.9<0;1,0>:f                   
        add (32|M0)              r23.0<1>:d    r15.0<1;1,0>:d    -r21.0<1;1,0>:d  {I@2}
        mov (32|M0)              r25.0<1>:ud   r19.0<1;1,0>:f                   {F@1}
(W)     add (1|M0)               r2.11<1>:d    (abs)r3.6<0;1,0>:d  -r2.10<0;1,0>:d {I@3}
        mov (32|M0)              r31.0<1>:f    r25.0<1;1,0>:ud                  {I@2}
        mov (32|M0)              r27.0<1>:f    r23.0<1;1,0>:ud                 
(W)     mov (1|M0)               r2.14<1>:f    r2.11<0;1,0>:ud                  {I@1}
        mad (32|M0)              acc0.0<1>:f   r17.0<1;0>:f      r31.0<1;0>:f      -r2.9<0>:f       {F@3}
        mad (32|M0)              acc2.0<1>:f   r27.0<1;0>:f      r31.0<1;0>:f      -r2.14<0>:f      {F@2}
        add (32|M0)              acc0.0<1>:f   acc0.0<1;1,0>:f   acc2.0<1;1,0>:f  {Compacted}
        mul (32|M0)              r29.0<1>:f    r2.13<0;1,0>:f    acc0.0<1;1,0>:f  {Compacted}
(W)     xor (1|M0)               cr0.0<1>:ud   cr0.0<0;1,0>:ud   0x30:uw              {A@1}
        mov (32|M0)              r33.0<1>:ud   r29.0<1;1,0>:f                   {A@1}
        add (32|M0)              r35.0<1>:d    r33.0<1;1,0>:d    r25.0<1;1,0>:d   {I@1}
(W)     mov (1|M0)               r2.15<1>:d    (abs)r3.6<0;1,0>:d              
(W)     mul (16|M0)              acc0.0<1>:d   r35.0<1;1,0>:d    r2.30<0;1,0>:uw  {I@1}
        macl (16|M0)             r37.0<1>:d    r35.0<1;1,0>:d    r2.15<0;1,0>:d   {Compacted}
(W)     mul (16|M16)             acc0.0<1>:d   r36.0<1;1,0>:d    r2.30<0;1,0>:uw 
        macl (16|M16)            r38.0<1>:d    r36.0<1;1,0>:d    r2.15<0;1,0>:d   {Compacted}
        add (32|M0)              r39.0<1>:d    r15.0<1;1,0>:d    -r37.0<1;1,0>:d  {I@1}
        cmp (32|M0)   (lt)f0.0   null<1>:ud    r39.0<1;1,0>:ud   r2.8<0;1,0>:ud   {I@1}
(~f0.0) sel (32|M0)              r46.0<1>:d    (abs)r3.6<0;1,0>:d  0:w            
        add3 (32|M0)             r41.0<1>:d    r39.0<1;0>:d      r11.0<1;0>:d      -r46.0<1>:d      {Compacted,I@1}
        xor (32|M0)              r43.0<1>:d    r41.0<1;1,0>:d    r11.0<1;1,0>:d   {Compacted,I@1}
(W)     jmpi                                 24                                
        mov (32|M0)              r43.0<1>:d    -1:w                               {Compacted}
        mov (16|M0)              r61.0<2>:ud   r43.0<1;1,0>:ud                  {Compacted,I@1}
        mov (16|M16)             r63.0<2>:ud   r44.0<1;1,0>:ud                  {Compacted}
        shl (16|M0)              r69.0<1>:q    r61.0<2;1,0>:d    2:w               {I@2}
        shl (16|M16)             r71.0<1>:q    r63.0<2;1,0>:d    2:w               {I@2}
        add (16|M0)              r48.0<1>:q    r69.0<1;1,0>:q    r2.3<0;1,0>:q    {Compacted,I@2}
        add (16|M16)             r50.0<1>:q    r71.0<1;1,0>:q    r2.3<0;1,0>:q    {Compacted,I@2}
        send.ugm (32|M0)         r53      r48  null:0  0x0            0x08200580           {I@1,$2} // wr:4+0, rd:2; load.ugm.d32.a64
(W)     mul (1|M0)               r3.10<1>:f    r3.5<0;1,0>:f     r3.8<0;1,0>:f   
        mov (16|M0)              r65.0<2>:ud   r6.0<1;1,0>:ud                   {Compacted}
        mov (16|M16)             r67.0<2>:ud   r7.0<1;1,0>:ud                  
        shl (16|M0)              r73.0<1>:q    r65.0<2;1,0>:d    2:w               {I@2}
        shl (16|M16)             r75.0<1>:q    r67.0<2;1,0>:d    2:w               {I@2}
        add (16|M0)              r57.0<1>:q    r73.0<1;1,0>:q    r3.0<0;1,0>:q    {Compacted,I@2}
        add (16|M16)             r59.0<1>:q    r75.0<1;1,0>:q    r3.0<0;1,0>:q    {Compacted,I@2}
        mad (32|M0)              acc0.0<1>:f   r3.3<0;0>:f       r53.0<1;0>:f      r3.2<0>:f        {$2.dst}
        mad (32|M0)              acc0.0<1>:f   r3.10<0;0>:f      acc0.0<1;0>:f     r3.4<0>:f        {F@2}
        add (32|M0)              r55.0<1>:f    acc0.0<1;1,0>:f   -r3.9<0;1,0>:f  
        send.ugm (32|M0)         null     r57  r55:2  0x0            0x08000584           {A@1,$3} // wr:4+2, rd:0; store.ugm.d32.a64
        join (32|M0)                         16                                
(W)     mov (16|M0)              r127.0<1>:f   r4.0<1;1,0>:f                   
(W)     send.gtwy (1|M0)         null     r127  null:0  0x0            0x02000010           {EOT,F@1,$4} // wr:1+0, rd:0; end of thread
(W)     mov (16|M0)              null<1>:ud    0xC98FA22F:ud                             
(W)     mov (16|M0)              null<1>:ud    0x330C2E64:ud                             
(W)     mov (16|M0)              null<1>:ud    0x0:ud                             
(W)     mov (16|M0)              null<1>:ud    0x3:ud                             
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
