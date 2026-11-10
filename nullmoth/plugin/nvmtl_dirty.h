/* SPDX-License-Identifier: MIT */
/* nvmtl_dirty.h: the dirty-only binding decisions of nvmtl_snapshot_set_c (nvmtl_vk.c), as pure functions over bit masks so
   a host program can check them (user/tests/metal/dirty_model.c) without Vulkan or a GPU.

   Per stage (`which`) the binding table keeps the last descriptor set built in this command buffer (t->last) with
     lastw    the bindings (indices < 256) that set holds valid descriptors for,
     last_hi  how many storage-texture bindings it holds,
     chg      the bindings whose slot changed since it was built (one bit per index, NVMTL_CHG_WORDS words),
     dirty    chg is not empty,
     gen      the object generation (nvmtl_vk_objgen) read when it was built.
   A draw then either binds that set again (reuse), binds it with a newer address table on the same page (was: only
   buffers changed and the pipeline reads them all through the table), or builds a new set; with dirty-only on, the new
   set copies the descriptors of the last one that did not change instead of writing them again.

   A slot is compared by handle (kind, VkImageView/VkSampler/VkBuffer pointer, offset). The same pointer can name another
   object once the first is destroyed (the allocator hands the address out again), so a descriptor the last set holds is
   trusted only while no image view, buffer view or sampler was destroyed since that set was built (same_gen); otherwise
   the set is not reused and nothing is copied from it. 2026-11-10: Safari's six-canvas WebGPU page drew white blocks and
   a stale rectangle of wallpaper with dirty-only on, and was right with NVMTL_NO_DIRTYONLY=1.

   The including file defines NVMTL_NBUF, NVMTL_STEX_BASE, NVMTL_NSTEX and NVMTL_CHG_WORDS. */
#ifndef NVMTL_DIRTY_H
#define NVMTL_DIRTY_H
#include <stdint.h>
#include <string.h>

#if !defined(NVMTL_NBUF) || !defined(NVMTL_STEX_BASE) || !defined(NVMTL_NSTEX) || !defined(NVMTL_CHG_WORDS)
#error "nvmtl_dirty.h needs NVMTL_NBUF, NVMTL_STEX_BASE, NVMTL_NSTEX and NVMTL_CHG_WORDS"
#endif

typedef struct {
    const uint64_t *pm;      /* 4 words: the bindings this pipeline's stage reads (indices < 256) */
    const uint64_t *lastw;   /* 4 words: the bindings the last set holds */
    const uint64_t *chg;     /* NVMTL_CHG_WORDS words */
    uint32_t hi, last_hi;    /* storage textures this pipeline reads / the last set holds */
    int have_last;           /* a last set exists, is this command buffer's and was built for the same texel-buffer mask */
    int dirty;
    int tabok;               /* the last set's address table holds the entries this stage reads */
    int same_gen;            /* no view or sampler was destroyed since the last set was built */
    int dirty_only;          /* NVMTL_NO_DIRTYONLY unset */
} nvmtl_ds_in;

/* every binding the pipeline reads is one the last set holds */
static inline int nvmtl_ds_covered(const uint64_t *pm, const uint64_t *lastw)
{
    for (int k = 0; k < 4; k++) if (pm[k] & ~lastw[k]) return 0;
    return 1;
}
/* nothing changed since the last set was built, and its descriptors can still be trusted */
static inline int nvmtl_ds_live(const nvmtl_ds_in *in) { return in->have_last && !in->dirty && in->same_gen; }

/* the last set serves this draw as it is */
static inline int nvmtl_ds_reuse(const nvmtl_ds_in *in)
{
    return nvmtl_ds_live(in) && in->tabok && in->hi <= in->last_hi && nvmtl_ds_covered(in->pm, in->lastw);
}

/* only buffer slots (indices 0..31) changed, or nothing did and only the table is short: the last set serves with a new
   address table on the same page (table_ubo), provided the pipeline reads no buffer descriptor that changed. The caller
   still checks the page and makes the table. */
static inline int nvmtl_ds_was(const nvmtl_ds_in *in, int table_ubo)
{
    if (!table_ubo || !in->have_last || !in->same_gen || !(in->dirty || !in->tabok) || in->hi > in->last_hi) return 0;
    if (in->dirty && (in->pm[0] & 0xffffffffull)) return 0;
    if (in->chg[0] >> 32) return 0;
    for (int k = 1; k < NVMTL_CHG_WORDS; k++) if (in->chg[k]) return 0;
    return nvmtl_ds_covered(in->pm, in->lastw);
}
/* The was path taken: the set's buffer descriptors of the changed slots are stale from now on, so they leave lastw
   (a later pipeline that reads one of them as a descriptor gets a new set). WAS: lastw kept them, chg was cleared, and
   the next pipeline that read such a buffer descriptor bound the set again with the old buffer in it. */
static inline void nvmtl_ds_was_taken(uint64_t *lastw, uint64_t *chg)
{
    lastw[0] &= ~(chg[0] & 0xffffffffull);
    memset(chg, 0, NVMTL_CHG_WORDS * sizeof *chg);
}

/* A new set. m: the bindings it is written for (the pipeline's, plus the last set's while that one is live, so a later
   pipeline that reads them can reuse it). *hi grows to last_hi likewise. Returns 1 when unchanged descriptors are copied
   from the last set; cm (NVMTL_CHG_WORDS words, every binding index including storage textures 63..127 at 256..320) then
   has a bit for each binding to copy. WAS: cm was 4 words and nvmtl_snapshot_set_md read cm[4] and cm[5] past it for
   storage textures 63 and up. */
static inline int nvmtl_ds_new(const nvmtl_ds_in *in, uint64_t m[4], uint32_t *hi, uint64_t cm[NVMTL_CHG_WORDS])
{
    const int live = nvmtl_ds_live(in);
    for (int k = 0; k < 4; k++) m[k] = in->pm[k] | (live ? in->lastw[k] : 0);
    if (live && in->last_hi > *hi) *hi = in->last_hi;
    memset(cm, 0, NVMTL_CHG_WORDS * sizeof *cm);
    if (!live || !in->dirty_only) return 0;
    for (int k = 0; k < 4; k++) cm[k] = in->lastw[k];
    for (uint32_t j = 0; j < NVMTL_NSTEX; j++) {
        const uint32_t i = NVMTL_STEX_BASE + j;
        if (j < in->last_hi) cm[i >> 6] |= 1ull << (i & 63); else cm[i >> 6] &= ~(1ull << (i & 63));
    }
    for (int k = 0; k < NVMTL_CHG_WORDS; k++) cm[k] &= ~in->chg[k];
    return 1;
}
#endif
