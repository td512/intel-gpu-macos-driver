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
(W)     mov (16|M0)              r123.0<1>:ud  r0.0<1;1,0>:ud                  
(W)     or (1|M0)                cr0.0<1>:ud   cr0.0<0;1,0>:ud   0x400004C0:ud              {A@1}
(W)     mul (1|M0)               acc0.0<1>:d   r3.3<0;1,0>:d     r123.2<0;1,0>:uw {A@1}
(W)     macl (1|M0)              r5.0<1>:d     r3.3<0;1,0>:d     r123.1<0;1,0>:d 
        add3 (32|M0)             r124.0<1>:d   r5.0<0;0>:d       r1.0<1;0>:uw      r3.0<0>:d        {@1,$0.dst}
        cmp (32|M0)   (lt)f0.0   null<1>:d     r124.0<1;1,0>:d   r4.2<0;1,0>:d    {@1,$1.dst}
(~f0.0) goto (32|M0)                         1536                  1536                
(W)     mul (1|M0)               acc0.0<1>:d   r3.4<0;1,0>:d     r123.12<0;1,0>:uw
(W)     macl (1|M0)              r9.0<1>:d     r3.4<0;1,0>:d     r123.6<0;1,0>:d 
        sel (32|M0)   (ge)f0.0   r5.0<1>:d     r124.0<1;1,0>:d   4:w              
        add3 (32|M0)             r15.0<1>:d    r9.0<0;0>:d       r2.0<1;0>:uw      r3.1<0>:d        {I@2}
        sel (32|M0)   (ge)f0.0   r7.0<1>:d     r124.0<1;1,0>:d   3:w              
        add (32|M0)              r11.0<1>:d    r5.0<1;1,0>:d     -4:w               {Compacted,I@3}
(W)     add (1|M0)               r10.0<1>:d    r4.2<0;1,0>:d     -1:w               {Compacted}
(W)     mul (16|M0)              acc0.0<1>:d   r15.0<1;1,0>:d    r4.4<0;1,0>:uw   {I@4}
        sel (32|M0)   (ge)f0.0   r17.0<1>:d    r124.0<1;1,0>:d   2:w              
        add (32|M0)              r13.0<1>:d    r7.0<1;1,0>:d     -3:w               {Compacted,I@5}
        macl (16|M0)             r27.0<1>:d    r15.0<1;1,0>:d    r4.2<0;1,0>:d    {Compacted}
(W)     mul (16|M16)             acc0.0<1>:d   r16.0<1;1,0>:d    r4.4<0;1,0>:uw  
        sel (32|M0)   (lt)f0.0   r19.0<1>:d    r10.0<0;1,0>:d    r11.0<1;1,0>:d   {I@6}
        macl (16|M16)            r28.0<1>:d    r16.0<1;1,0>:d    r4.2<0;1,0>:d    {Compacted}
        sel (32|M0)   (ge)f0.0   r21.0<1>:d    r124.0<1;1,0>:d   1:w              
        add (32|M0)              r23.0<1>:d    r17.0<1;1,0>:d    -2:w               {Compacted,I@7}
        sel (32|M0)   (lt)f0.0   r25.0<1>:d    r10.0<0;1,0>:d    r13.0<1;1,0>:d   {I@7}
        add (32|M0)              r39.0<1>:d    r27.0<1;1,0>:d    r19.0<1;1,0>:d   {Compacted,I@4}
        add (32|M0)              r29.0<1>:d    r21.0<1;1,0>:d    -1:w               {Compacted,I@4}
        sel (32|M0)   (lt)f0.0   r31.0<1>:d    r10.0<0;1,0>:d    r23.0<1;1,0>:d   {I@4}
        add (32|M0)              r41.0<1>:d    r27.0<1;1,0>:d    r25.0<1;1,0>:d   {Compacted,I@4}
        sel (32|M0)   (ge)f0.0   r33.0<1>:d    r124.0<1;1,0>:d   -1:w              
        mov (16|M0)              r47.0<2>:ud   r39.0<1;1,0>:ud                  {Compacted,I@5}
        mov (16|M16)             r49.0<2>:ud   r40.0<1;1,0>:ud                  {Compacted}
        sel (32|M0)   (ge)f0.0   r37.0<1>:d    r124.0<1;1,0>:d   0:w              
        sel (32|M0)   (lt)f0.0   r35.0<1>:d    r10.0<0;1,0>:d    r29.0<1;1,0>:d   {I@7}
        add (32|M0)              r43.0<1>:d    r27.0<1;1,0>:d    r31.0<1;1,0>:d   {Compacted,I@7}
        sel (32|M0)   (ge)f0.0   r55.0<1>:d    r124.0<1;1,0>:d   -2:w              
        mov (16|M0)              r51.0<2>:ud   r41.0<1;1,0>:ud                  {Compacted,I@7}
        mov (16|M16)             r53.0<2>:ud   r42.0<1;1,0>:ud                  {Compacted}
        add (32|M0)              r45.0<1>:d    r33.0<1;1,0>:d    1:w               {I@7}
        shl (16|M0)              r57.0<1>:q    r47.0<2;1,0>:d    2:w               {I@7}
        shl (16|M16)             r59.0<1>:q    r49.0<2;1,0>:d    2:w               {I@7}
        sel (32|M0)   (lt)f0.0   r63.0<1>:d    r10.0<0;1,0>:d    r37.0<1;1,0>:d   {I@7}
        add (32|M0)              r61.0<1>:d    r27.0<1;1,0>:d    r35.0<1;1,0>:d   {Compacted,I@7}
        sel (32|M0)   (ge)f0.0   r79.0<1>:d    r124.0<1;1,0>:d   -3:w              
        mov (16|M0)              r69.0<2>:ud   r43.0<1;1,0>:ud                  {Compacted,I@7}
        mov (16|M16)             r71.0<2>:ud   r44.0<1;1,0>:ud                  {Compacted}
        add (32|M0)              r77.0<1>:d    r55.0<1;1,0>:d    2:w               {Compacted,I@7}
        shl (16|M0)              r65.0<1>:q    r51.0<2;1,0>:d    2:w               {I@7}
        shl (16|M16)             r67.0<1>:q    r53.0<2;1,0>:d    2:w               {I@7}
        add (16|M0)              r73.0<1>:q    r57.0<1;1,0>:q    r3.3<0;1,0>:q    {Compacted,I@7}
        add (16|M16)             r75.0<1>:q    r59.0<1;1,0>:q    r3.3<0;1,0>:q    {Compacted,I@7}
        sel (32|M0)   (lt)f0.0   r83.0<1>:d    r10.0<0;1,0>:d    r45.0<1;1,0>:d  
        add (32|M0)              r81.0<1>:d    r27.0<1;1,0>:d    r63.0<1;1,0>:d   {Compacted,I@7}
        send.ugm (32|M0)         r97      r73  null:0  0x0            0x08200580           {I@3,$2} // wr:4+0, rd:2; load.ugm.d32.a64
        sel (32|M0)   (ge)f0.0   r101.0<1>:d   r124.0<1;1,0>:d   -4:w              
        mov (16|M0)              r89.0<2>:ud   r61.0<1;1,0>:ud                  {Compacted}
        mov (16|M16)             r91.0<2>:ud   r62.0<1;1,0>:ud                  {Compacted}
        add (32|M0)              r99.0<1>:d    r79.0<1;1,0>:d    3:w               {Compacted}
        shl (16|M0)              r85.0<1>:q    r69.0<2;1,0>:d    2:w              
        shl (16|M16)             r87.0<1>:q    r71.0<2;1,0>:d    2:w              
        add (16|M0)              r93.0<1>:q    r65.0<1;1,0>:q    r3.3<0;1,0>:q    {Compacted}
        add (16|M16)             r95.0<1>:q    r67.0<1;1,0>:q    r3.3<0;1,0>:q    {Compacted}
        sel (32|M0)   (lt)f0.0   r105.0<1>:d   r10.0<0;1,0>:d    r77.0<1;1,0>:d  
        add (32|M0)              r103.0<1>:d   r27.0<1;1,0>:d    r83.0<1;1,0>:d   {Compacted,I@7}
        send.ugm (32|M0)         r119     r93  null:0  0x0            0x08200580           {I@3,$3} // wr:4+0, rd:2; load.ugm.d32.a64
        mov (16|M0)              r111.0<2>:ud  r81.0<1;1,0>:ud                  {Compacted}
        mov (16|M16)             r113.0<2>:ud  r82.0<1;1,0>:ud                  {Compacted}
        add (32|M0)              r121.0<1>:d   r101.0<1;1,0>:d   4:w               {Compacted}
        shl (16|M0)              r107.0<1>:q   r89.0<2;1,0>:d    2:w              
        shl (16|M16)             r109.0<1>:q   r91.0<2;1,0>:d    2:w              
        add (16|M0)              r115.0<1>:q   r85.0<1;1,0>:q    r3.3<0;1,0>:q    {Compacted}
        add (16|M16)             r117.0<1>:q   r87.0<1;1,0>:q    r3.3<0;1,0>:q    {Compacted}
        sel (32|M0)   (lt)f0.0   r5.0<1>:d     r10.0<0;1,0>:d    r99.0<1;1,0>:d  
        add (32|M0)              r1.0<1>:d     r27.0<1;1,0>:d    r105.0<1;1,0>:d  {I@7}
        send.ugm (32|M0)         r21      r115  null:0  0x0            0x08200580           {I@3,$4} // wr:4+0, rd:2; load.ugm.d32.a64
        mov (16|M0)              r13.0<2>:ud   r103.0<1;1,0>:ud                 {Compacted}
        mov (16|M16)             r15.0<2>:ud   r104.0<1;1,0>:ud                 {Compacted}
        shl (16|M0)              r7.0<1>:q     r111.0<2;1,0>:d   2:w              
        shl (16|M16)             r11.0<1>:q    r113.0<2;1,0>:d   2:w              
        add (16|M0)              r17.0<1>:q    r107.0<1;1,0>:q   r3.3<0;1,0>:q    {Compacted}
        add (16|M16)             r19.0<1>:q    r109.0<1;1,0>:q   r3.3<0;1,0>:q    {Compacted}
        sel (32|M0)   (lt)f0.0   r25.0<1>:d    r10.0<0;1,0>:d    r121.0<1;1,0>:d 
        add (32|M0)              r23.0<1>:d    r27.0<1;1,0>:d    r5.0<1;1,0>:d    {Compacted,I@7}
        send.ugm (32|M0)         r41      r17  null:0  0x0            0x08200580           {I@3,$5} // wr:4+0, rd:2; load.ugm.d32.a64
        mov (16|M0)              r33.0<2>:ud   r1.0<1;1,0>:ud                   {Compacted}
        mov (16|M16)             r35.0<2>:ud   r2.0<1;1,0>:ud                   {Compacted}
        shl (16|M0)              r29.0<1>:q    r13.0<2;1,0>:d    2:w              
        shl (16|M16)             r31.0<1>:q    r15.0<2;1,0>:d    2:w              
        add (16|M0)              r37.0<1>:q    r7.0<1;1,0>:q     r3.3<0;1,0>:q    {Compacted}
        add (16|M16)             r39.0<1>:q    r11.0<1;1,0>:q    r3.3<0;1,0>:q    {Compacted}
        add (32|M0)              r43.0<1>:d    r27.0<1;1,0>:d    r25.0<1;1,0>:d   {Compacted,I@7}
        send.ugm (32|M0)         r57      r37  null:0  0x0            0x08200580           {I@2,$6} // wr:4+0, rd:2; load.ugm.d32.a64
        mov (16|M0)              r49.0<2>:ud   r23.0<1;1,0>:ud                  {Compacted}
        mov (16|M16)             r51.0<2>:ud   r24.0<1;1,0>:ud                  {Compacted}
        shl (16|M0)              r45.0<1>:q    r33.0<2;1,0>:d    2:w              
        shl (16|M16)             r47.0<1>:q    r35.0<2;1,0>:d    2:w              
        add (16|M0)              r53.0<1>:q    r29.0<1;1,0>:q    r3.3<0;1,0>:q    {Compacted}
        add (16|M16)             r55.0<1>:q    r31.0<1;1,0>:q    r3.3<0;1,0>:q    {Compacted}
        send.ugm (32|M0)         r71      r53  null:0  0x0            0x08200580           {I@1,$7} // wr:4+0, rd:2; load.ugm.d32.a64
        mov (16|M0)              r63.0<2>:ud   r43.0<1;1,0>:ud                  {Compacted}
        mov (16|M16)             r65.0<2>:ud   r44.0<1;1,0>:ud                  {Compacted}
        shl (16|M0)              r59.0<1>:q    r49.0<2;1,0>:d    2:w              
        shl (16|M16)             r61.0<1>:q    r51.0<2;1,0>:d    2:w              
        add (16|M0)              r67.0<1>:q    r45.0<1;1,0>:q    r3.3<0;1,0>:q    {Compacted}
        add (16|M16)             r69.0<1>:q    r47.0<1;1,0>:q    r3.3<0;1,0>:q    {Compacted}
        send.ugm (32|M0)         r81      r67  null:0  0x0            0x08200580           {I@1,$8} // wr:4+0, rd:2; load.ugm.d32.a64
        shl (16|M0)              r73.0<1>:q    r63.0<2;1,0>:d    2:w               {$2.src}
        shl (16|M16)             r75.0<1>:q    r65.0<2;1,0>:d    2:w              
        add (16|M0)              r77.0<1>:q    r59.0<1;1,0>:q    r3.3<0;1,0>:q    {Compacted}
        add (16|M16)             r79.0<1>:q    r61.0<1;1,0>:q    r3.3<0;1,0>:q    {Compacted}
        send.ugm (32|M0)         r89      r77  null:0  0x0            0x08200580           {I@1,$9} // wr:4+0, rd:2; load.ugm.d32.a64
        add (16|M0)              r83.0<1>:q    r73.0<1;1,0>:q    r3.3<0;1,0>:q    {Compacted}
        add (16|M16)             r85.0<1>:q    r75.0<1;1,0>:q    r3.3<0;1,0>:q    {Compacted}
        send.ugm (32|M0)         r99      r83  null:0  0x0            0x08200580           {I@1,$10} // wr:4+0, rd:2; load.ugm.d32.a64
(W)     mov (1|M0)               r91.0<1>:f    0.0:f                               {Compacted}
(W)     mov (1|M0)               r88.0<1>:f    0.0162:f                              
(W)     mov (1|M0)               r92.0<1>:f    0.054:f                              
        mad (32|M0)              acc0.0<1>:f   r91.0<0;0>:f      r97.0<1;0>:f      r88.0<0>:f       {Compacted,@2,$2.dst}
(W)     mov (1|M0)               r94.0<1>:f    0.1216:f                               {$3.src}
        mad (32|M0)              acc0.0<1>:f   acc0.0<1;0>:f     r119.0<1;0>:f     r92.0<0>:f       {Compacted,@3,$3.dst}
(W)     mov (1|M0)               r96.0<1>:f    0.1945:f                              
        mad (32|M0)              acc0.0<1>:f   acc0.0<1;0>:f     r21.0<1;0>:f      r94.0<0>:f       {Compacted,@3,$4.dst}
(W)     mov (1|M0)               r102.0<1>:f   0.227:f                              
        mad (32|M0)              acc0.0<1>:f   acc0.0<1;0>:f     r41.0<1;0>:f      r96.0<0>:f       {Compacted,@3,$5.dst}
        mad (32|M0)              acc0.0<1>:f   acc0.0<1;0>:f     r57.0<1;0>:f      r102.0<0>:f      {Compacted,@2,$6.dst}
        add (32|M0)              r103.0<1>:d   r27.0<1;1,0>:d    r124.0<1;1,0>:d  {Compacted}
        mad (32|M0)              acc0.0<1>:f   acc0.0<1;0>:f     r71.0<1;0>:f      r96.0<0>:f       {Compacted,$7.dst}
        mov (16|M0)              r105.0<2>:ud  r103.0<1;1,0>:ud                 {Compacted,I@1}
        mov (16|M16)             r107.0<2>:ud  r104.0<1;1,0>:ud                 {Compacted}
        mad (32|M0)              acc0.0<1>:f   acc0.0<1;0>:f     r81.0<1;0>:f      r94.0<0>:f       {$8.dst}
        shl (16|M0)              r109.0<1>:q   r105.0<2;1,0>:d   2:w               {I@2}
        shl (16|M16)             r111.0<1>:q   r107.0<2;1,0>:d   2:w               {I@2}
        mad (32|M0)              acc0.0<1>:f   acc0.0<1;0>:f     r89.0<1;0>:f      r92.0<0>:f       {Compacted,$9.dst}
        add (16|M0)              r113.0<1>:q   r109.0<1;1,0>:q   r4.0<0;1,0>:q    {Compacted,I@2}
        add (16|M16)             r115.0<1>:q   r111.0<1;1,0>:q   r4.0<0;1,0>:q    {Compacted,I@2}
        mad (32|M0)              r117.0<1>:f   acc0.0<1;0>:f     r99.0<1;0>:f      r88.0<0>:f       {Compacted,$10.dst}
        send.ugm (32|M0)         null     r113  r117:2  0x0            0x08000584           {A@1,$11} // wr:4+2, rd:0; store.ugm.d32.a64
        join (32|M0)                         16                                
(W)     mov (16|M0)              r127.0<1>:f   r123.0<1;1,0>:f                 
(W)     send.gtwy (1|M0)         null     r127  null:0  0x0            0x02000010           {EOT,F@1,$12} // wr:1+0, rd:0; end of thread
(W)     mov (16|M0)              null<1>:ud    0xC98FA22F:ud                             
(W)     mov (16|M0)              null<1>:ud    0x330C2E64:ud                             
(W)     mov (16|M0)              null<1>:ud    0x0:ud                             
(W)     mov (16|M0)              null<1>:ud    0xA:ud                             
        illegal                
        illegal                
        illegal                
        illegal                
        illegal                
        illegal                
        illegal                
        illegal                
