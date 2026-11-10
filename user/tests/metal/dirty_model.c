// SPDX-License-Identifier: MIT
// dirty_model: a host model of the Metal plugin's dirty-only descriptor sets (nvmtl_snapshot_set_c in nvmtl_vk.c) that runs
// the plugin's own decision functions (nullmoth/plugin/nvmtl_dirty.h) without Vulkan or a GPU, on any Mac.
//
// Modelled: binding slots by (kind, pointer, offset) as nvmtl_bind_slot compares them; objects that live at an address,
// destroyed and made again at the same address (what the allocator does, and what a slot comparison cannot see); the
// object generation the plugin bumps on every view / sampler destroy; descriptor sets taken from a recycled pool with old
// contents; nvmtl_snapshot_set_md's writes and copies; the address table that a reused set keeps and the "was" path
// renews; pipelines with random binding masks (buffer descriptors or table-only, storage textures up to 127).
// Checked after every draw: each binding the pipeline reads holds the descriptor of the object its slot names now, and
// a table-reading pipeline sees every buffer's current address.
//
//   clang -O2 -Wall -o dirty_model dirty_model.c && ./dirty_model [steps=2000000] [seed=1]
//   ./dirty_model 200000 1 old     the logic before 2026-11-10 (expected to FAIL: shows what the model catches);
//                                  1, 2 or 4 instead of old: only one of its three holes (no object generation, lastw
//                                  kept on the was path, the 4-word copy mask)
//   ./dirty_model 200000 1 old 0   the same with NVMTL_NO_DIRTYONLY=1 (no copies; reuse and the was path stay)
//   clang -O1 -g -fsanitize=address,undefined -o dirty_model_asan dirty_model.c && ./dirty_model_asan 200000
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

/* nvmtl_vk.c's binding space */
#define NVMTL_NBUF 32
#define NVMTL_NTEX 128
#define NVMTL_NSAMP 32
#define NVMTL_ADDRESS_BINDING (NVMTL_NBUF + NVMTL_NTEX + NVMTL_NSAMP)
#define NVMTL_NSTEX 128
#define NVMTL_STEX_BASE (NVMTL_ADDRESS_BINDING + 1)
#define NVMTL_NBIND (NVMTL_STEX_BASE + NVMTL_NSTEX)
#define NVMTL_CHG_WORDS ((NVMTL_NBIND + 63) / 64)
#include "../../../nullmoth/plugin/nvmtl_dirty.h"

enum { NONE = 0, BUF, TEX, SAMP };
enum { NADDR = 6, NPIPE = 12, NSETS = 4096, DUMMY = -1 };

static uint64_t rng = 1;
static uint32_t rnd(void) { rng ^= rng << 13; rng ^= rng >> 7; rng ^= rng << 17; return (uint32_t)rng; }
static uint32_t below(uint32_t n) { return rnd() % n; }

/* objects: per kind, NADDR addresses, each with the id of the object living there (ids never repeat) */
static int64_t live_at[4][NADDR];
static int64_t next_id = 1;
static uint64_t objgen = 1;
static int dirty_only = 1;   /* argv[4] = 0: as NVMTL_NO_DIRTYONLY=1 */
static int old_logic;   /* bits of the logic before 2026-11-10: 1 no object generation, 2 lastw kept on the was path,
                           4 a 4-word copy mask (md read two words past it) */

typedef struct { uint8_t kind; uint8_t addr; uint32_t off; } slot_t;
static slot_t slots[NVMTL_NBIND];

/* what nvmtl_snapshot_set_md writes for a slot, as the object it names now */
static int64_t desc_of(uint32_t i)
{
    const slot_t *s = &slots[i];
    const int want = i < NVMTL_NBUF ? BUF : i < NVMTL_NBUF + NVMTL_NTEX ? TEX : i < NVMTL_ADDRESS_BINDING ? SAMP : TEX;
    if (s->kind != want) return DUMMY;
    const int64_t id = live_at[s->kind][s->addr];
    return s->kind == BUF ? id * 4096 + s->off : id;
}

typedef struct { int64_t d[NVMTL_NBIND]; } set_t;
static set_t sets[NSETS];
static int nused;   /* sets of this command buffer: 0..nused-1; the rest hold whatever an earlier command buffer left */

typedef struct { uint64_t pm[4]; uint32_t hi; int table; } pipe_t;
static pipe_t pipes[NPIPE];

/* the binding table's per-stage state (one stage is enough: the two never mix) */
static struct {
    int last; uint64_t lastw[4]; uint64_t chg[NVMTL_CHG_WORDS]; int dirty; uint32_t last_hi; uint64_t lastgen;
    int64_t lasttab[NVMTL_NBUF]; int tabok;
} T;

static void mark(uint32_t i) { T.dirty = 1; T.chg[i >> 6] |= 1ull << (i & 63); }
/* nvmtl_bind_slot: the slot changed when its kind, pointer or offset did */
static void bind(uint32_t i, uint8_t kind, uint8_t addr, uint32_t off)
{
    slot_t *s = &slots[i];
    if (s->kind != kind || s->addr != addr || s->off != off) mark(i);
    s->kind = kind; s->addr = addr; s->off = off;
}

static void new_cb(void)
{
    memset(&T, 0, sizeof T); T.last = -1;
    memset(slots, 0, sizeof slots);   /* a pooled table is all zero */
    /* the sets of the last command buffer go back to the pool with their contents; scramble a few as other users would */
    for (int k = 0; k < nused; k++) if (below(4) == 0) for (uint32_t i = 0; i < NVMTL_NBIND; i++) sets[k].d[i] = -2 - (int64_t)below(1000000);
    nused = 0;
}

/* --- the logic before 2026-11-10, for "old": no generation, lastw kept on the was path, a 4-word copy mask --- */
static void old_was_taken(uint64_t *lastw, uint64_t *chg) { (void)lastw; memset(chg, 0, NVMTL_CHG_WORDS * sizeof *chg); }
static int old_new(const nvmtl_ds_in *in, uint64_t m[4], uint32_t *hi, uint64_t cm[NVMTL_CHG_WORDS])
{
    const int live = nvmtl_ds_live(in);
    for (int k = 0; k < 4; k++) m[k] = in->pm[k] | (live ? in->lastw[k] : 0);
    if (live && in->last_hi > *hi) *hi = in->last_hi;
    memset(cm, 0, NVMTL_CHG_WORDS * sizeof *cm);
    if (!live || !in->dirty_only) return 0;
    for (int k = 0; k < 4; k++) cm[k] = in->lastw[k];
    for (uint32_t j = 0; j < NVMTL_NSTEX && NVMTL_STEX_BASE + j < 256; j++) {
        const uint32_t i = NVMTL_STEX_BASE + j;
        if (j < in->last_hi) cm[i >> 6] |= 1ull << (i & 63); else cm[i >> 6] &= ~(1ull << (i & 63));
    }
    for (int k = 0; k < 4; k++) cm[k] &= ~in->chg[k];
    cm[4] = ((uint64_t)rnd() << 32) | rnd(); cm[5] = ((uint64_t)rnd() << 32) | rnd();   /* what md read past the array */
    return 1;
}

static long failures, draws, reuses, wases, copies;
static int64_t drawtab[NVMTL_NBUF];

static void check(const pipe_t *p, const set_t *s, const int64_t *tab, long step)
{
    long bad = 0; uint32_t first = 0;
    for (uint32_t i = 0; i < NVMTL_STEX_BASE; i++) {
        if (i == NVMTL_ADDRESS_BINDING || !((p->pm[i >> 6] >> (i & 63)) & 1)) continue;
        if (s->d[i] != desc_of(i)) { if (!bad++) first = i; }
    }
    for (uint32_t j = 0; j < p->hi; j++) if (s->d[NVMTL_STEX_BASE + j] != desc_of(NVMTL_STEX_BASE + j)) { if (!bad++) first = NVMTL_STEX_BASE + j; }
    if (p->table) for (uint32_t b = 0; b < NVMTL_NBUF; b++) if (tab[b] != desc_of(b)) { if (!bad++) first = 1000 + b; }
    if (!bad) return;
    if (failures < 10) fprintf(stderr, "step %ld: %ld stale binding(s), first %u%s\n", step, bad, first >= 1000 ? first - 1000 : first,
                               first >= 1000 ? " (address table)" : "");
    failures++;
}

static void draw(const pipe_t *p, long step)
{
    draws++;
    for (uint32_t b = 0; b < NVMTL_NBUF; b++) drawtab[b] = desc_of(b);   /* a table snapshot as the slots stand */
    const nvmtl_ds_in in = { p->pm, T.lastw, T.chg, p->hi, T.last_hi, T.last >= 0, T.dirty, T.tabok,
                             (old_logic & 1) ? 1 : T.lastgen == objgen, dirty_only };
    if (nvmtl_ds_reuse(&in)) { reuses++; check(p, &sets[T.last], T.lasttab, step); return; }
    if (nvmtl_ds_was(&in, 1)) {
        wases++;
        if (p->table) { memcpy(T.lasttab, drawtab, sizeof drawtab); T.tabok = 1; }
        T.dirty = 0; ((old_logic & 2) ? old_was_taken : nvmtl_ds_was_taken)(T.lastw, T.chg);
        check(p, &sets[T.last], p->table ? T.lasttab : drawtab, step);
        return;
    }
    uint64_t m[4], cm[NVMTL_CHG_WORDS]; uint32_t hi = p->hi;
    const int copy = ((old_logic & 4) ? old_new : nvmtl_ds_new)(&in, m, &hi, cm);
    if (nused == NSETS) { fprintf(stderr, "out of sets\n"); exit(2); }
    set_t *s = &sets[nused]; const set_t *from = copy ? &sets[T.last] : NULL;
    if (copy) copies++;
    /* nvmtl_snapshot_set_md: every binding in m is written or copied; buffers are always written */
    for (uint32_t i = 0; i < NVMTL_STEX_BASE; i++) {
        if (i == NVMTL_ADDRESS_BINDING || !((m[i >> 6] >> (i & 63)) & 1)) continue;
        if (i >= NVMTL_NBUF && from && ((cm[i >> 6] >> (i & 63)) & 1)) s->d[i] = from->d[i];
        else s->d[i] = desc_of(i);
    }
    for (uint32_t j = 0; j < hi && j < NVMTL_NSTEX; j++) {
        const uint32_t i = NVMTL_STEX_BASE + j;
        if (from && ((cm[i >> 6] >> (i & 63)) & 1)) s->d[i] = from->d[i]; else s->d[i] = desc_of(i);
    }
    T.last = nused++; memcpy(T.lastw, m, sizeof m); T.last_hi = hi; T.dirty = 0; memset(T.chg, 0, sizeof T.chg);
    T.lastgen = objgen; memcpy(T.lasttab, drawtab, sizeof drawtab); T.tabok = 1;
    check(p, s, T.lasttab, step);
}

static void make_pipes(void)
{
    for (int k = 0; k < NPIPE; k++) {
        pipe_t *p = &pipes[k]; memset(p, 0, sizeof *p);
        const int tableOnly = below(3) == 0;   /* reaches every buffer through the address table: the was path */
        for (uint32_t i = 0; i < NVMTL_STEX_BASE; i++) {
            if (i < NVMTL_NBUF && tableOnly) continue;
            if (i == NVMTL_ADDRESS_BINDING || below(i < NVMTL_NBUF ? 8 : 20) == 0) p->pm[i >> 6] |= 1ull << (i & 63);
        }
        p->table = 1;
        const uint32_t r = below(10);
        p->hi = r < 5 ? 0 : r < 8 ? below(8) : below(NVMTL_NSTEX + 1);   /* now and then past 63 (bindings 256..320) */
    }
}

int main(int argc, char **argv)
{
    const long steps = argc > 1 ? atol(argv[1]) : 2000000;
    rng = argc > 2 ? strtoull(argv[2], NULL, 10) * 2654435761ull + 1 : 1;
    old_logic = argc > 3 ? (!strcmp(argv[3], "old") ? 7 : atoi(argv[3]) & 7) : 0;
    dirty_only = argc > 4 ? atoi(argv[4]) != 0 : 1;
    for (int k = 0; k < 4; k++) for (int a = 0; a < NADDR; a++) live_at[k][a] = next_id++;
    for (long i = 0; i < NSETS; i++) for (uint32_t b = 0; b < NVMTL_NBIND; b++) sets[i].d[b] = -2 - (int64_t)below(1000000);
    make_pipes(); new_cb();
    long aba = 0;
    for (long step = 0; step < steps; step++) {
        const uint32_t op = below(100);
        if (op < 8) bind(below(NVMTL_NBUF), BUF, (uint8_t)below(NADDR), below(4) * 256);
        else if (op < 20) bind(NVMTL_NBUF + below(16), below(10) ? TEX : NONE, (uint8_t)below(NADDR), 0);
        else if (op < 24) bind(NVMTL_NBUF + NVMTL_NTEX + below(8), below(10) ? SAMP : NONE, (uint8_t)below(NADDR), 0);
        else if (op < 28) { const uint32_t j = below(4) == 0 ? 60 + below(68) : below(8); bind(NVMTL_STEX_BASE + j, below(10) ? TEX : NONE, (uint8_t)below(NADDR), 0); }
        else if (op < 31) {
            /* a texture or sampler destroyed and another made at its address, then bound where the first was:
               the slot comparison sees the same pointer */
            const int kind = below(4) ? TEX : SAMP; const uint8_t a = (uint8_t)below(NADDR);
            objgen++; live_at[kind][a] = next_id++; aba++;
            for (uint32_t i = NVMTL_NBUF; i < NVMTL_NBIND; i++) if (slots[i].kind == kind && slots[i].addr == a) bind(i, (uint8_t)kind, a, 0);
        } else if (op < 32) {
            /* a buffer made again at its address and bound again: nvmtl_vk_bind_buffer compares the device address too */
            const uint8_t a = (uint8_t)below(NADDR); live_at[BUF][a] = next_id++;
            for (uint32_t i = 0; i < NVMTL_NBUF; i++) if (slots[i].kind == BUF && slots[i].addr == a) mark(i);
        } else if (op < 33) { if (T.last >= 0) T.tabok = 0; }   /* a stage that reads more table entries than the last held */
        else if (op < 34 || nused > NSETS - 8) new_cb();
        else draw(&pipes[below(NPIPE)], step);
    }
    printf("dirty_model%s%s: %ld draws (%ld set reuses, %ld table-only renewals, %ld new sets copying unchanged descriptors), "
           "%ld destroy+remake at the same address: %ld FAILED\n", old_logic ? " (old logic)" : "", dirty_only ? "" : " (no dirty-only)", draws, reuses, wases, copies, aba, failures);
    return failures ? 1 : 0;
}
