// SPDX-License-Identifier: MIT
/* GPU-encoded indirect command buffers: the slot record layout shared with the translator
   (translator/translator/src/native/render_command.rs, which lowers air.draw_primitives_render_command,
   air.draw_indexed_primitives_render_command.p1i16/.p1i32 and air.reset_render_command to stores into it).

   An MTLIndirectCommandBuffer whose gpuResourceID is taken (an argument encoder's setIndirectCommandBuffer:atIndex:
   or the app itself) gets a record buffer (VRAM through the BAR when it can, else system RAM; the CPU keeps its own copy
   of what it wrote and never reads the buffer back): one 64-byte record per slot. Its device address is the
   gpuResourceID, which is what a shader's `command_buffer` holds. The CPU writes a record when the app encodes a draw
   through indirectRenderCommandAtIndex:, the GPU when a shader encodes one; executeCommandsInBuffer:withRange: then
   draws every slot from its record with vkCmdDrawIndexedIndirect (a slot with an index buffer) or vkCmdDrawIndirect,
   so the last writer wins on either side, as on Apple's GPUs.

   Words (uint32):
     0      kind: NVMTL_ICB_EMPTY / _DRAW / _INDEXED / _REFUSED                                      CPU + GPU
     1      Metal primitive type of the last draw written                                            CPU + GPU
     2..6   VkDrawIndexedIndirectCommand                                                             CPU + GPU
     7..10  VkDrawIndirectCommand                                                                    CPU + GPU
     11     primitive type the execute draws the slot with (NVMTL_ICB_NO_PRIM: none chosen yet)       CPU
     12,13  device address bound as the slot's index buffer (0: none)                                CPU
     14     bytes from that address to the end of the index buffer                                   CPU
     15     log2 of the index size (1 uint16, 2 uint32, 0 none)                                      CPU
   A write zeroes the counts of the form it does not use. The execute issues one draw per slot: the indexed form when
   word 15 is non-zero, else the plain form (both, until 11 Nov 2026: Xe2 ANV loads each indirect parameter with its
   own MI_LOAD_REGISTER_MEM, ~2.2 us per indirect draw from VRAM and ~5 us from system RAM, user/tests/metal/
   mtl_icb_cost.m). Topology and index buffer are bound by the CPU (core Vulkan takes neither from GPU memory), so a GPU
   draw with another primitive type than word 11, another index type than word 15, an index pointer outside
   [word 12/13, + word 14], or a plain draw into a slot with an index buffer is written with zero counts and kind
   NVMTL_ICB_REFUSED. */
#ifndef NVMTL_ICB_LAYOUT_H
#define NVMTL_ICB_LAYOUT_H
#include <stdint.h>

enum {
    NVMTL_ICB_RECORD_BYTES = 64,
    NVMTL_ICB_W_KIND = 0, NVMTL_ICB_W_PRIM = 1, NVMTL_ICB_W_IDX = 2, NVMTL_ICB_W_DRAW = 7,
    NVMTL_ICB_W_EXEC_PRIM = 11, NVMTL_ICB_W_IB_LO = 12, NVMTL_ICB_W_IB_HI = 13, NVMTL_ICB_W_IB_LIMIT = 14, NVMTL_ICB_W_IB_SHIFT = 15,
    NVMTL_ICB_EMPTY = 0, NVMTL_ICB_DRAW = 1, NVMTL_ICB_INDEXED = 2, NVMTL_ICB_REFUSED = 3,
};
#define NVMTL_ICB_NO_PRIM 0xffffffffu

typedef struct {
    uint32_t kind, prim;
    uint32_t idx[5];    /* indexCount, instanceCount, firstIndex, vertexOffset, firstInstance */
    uint32_t draw[4];   /* vertexCount, instanceCount, firstVertex, firstInstance */
    uint32_t execPrim, ibLo, ibHi, ibLimit, ibShift;
} nvmtl_icb_record;
_Static_assert(sizeof(nvmtl_icb_record) == NVMTL_ICB_RECORD_BYTES, "the translator addresses a slot as 16 words");
_Static_assert(__builtin_offsetof(nvmtl_icb_record, idx) == NVMTL_ICB_W_IDX * 4, "indexed draw at word 2");
_Static_assert(__builtin_offsetof(nvmtl_icb_record, draw) == NVMTL_ICB_W_DRAW * 4, "plain draw at word 7");
_Static_assert(__builtin_offsetof(nvmtl_icb_record, execPrim) == NVMTL_ICB_W_EXEC_PRIM * 4, "execute topology at word 11");
_Static_assert(__builtin_offsetof(nvmtl_icb_record, ibShift) == NVMTL_ICB_W_IB_SHIFT * 4, "index shift at word 15");

/* The pipeline's topology class gives the primitive type of a slot that has no CPU-encoded draw:
   MTLPrimitiveTopologyClass Point 1 -> point (0), Line 2 -> line (1), Triangle 3 / Unspecified 0 -> triangle (3). */
static inline uint32_t nvmtl_icb_prim_for_class(unsigned long cls) { return cls == 1 ? 0u : cls == 2 ? 1u : 3u; }
#endif
