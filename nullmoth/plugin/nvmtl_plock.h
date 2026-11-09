/* nvmtl_plock.h - NVMTL_LOCK_V2: commit and the execution worker without the process-wide command-buffer class lock.

   The old path (NVMTLEventSync.m) holds @synchronized ([NVMTLCommandBuffer class]) across the commit-time submit-ahead
   pass, i.e. across vkQueueSubmit and its exec ioctl, and the execution worker takes the same lock four to six times per
   command buffer (eligibility, the part claim, the surface-writer map in nvmtlFinishExecution, completion, -dealloc's
   pump, the generation check). With one tiny dispatch per command buffer both threads spent a third of their time
   handing that lock to each other (cbcost back to back: 18-21 us per command buffer, sample 2026-11-09).

   V2 splits what the lock protected:
     state lock    (os_unfair_lock, short, leaf)   the pending list, the pumping flag and generation, every queue's
                                                    reservations; nothing is submitted, waited for or released to zero
                                                    under it
     ahead lock    (os_unfair_lock, trylock only)   one submit-ahead pass at a time (pass order = GPU order per queue,
                                                    the evfold promise map, _nextSubmit); a thread that finds it held
                                                    marks the pass dirty and the holder runs it again (a combiner), so
                                                    nobody ever blocks on it
     part state    (atomic per part)               the hand-off of a part between the pass and the worker that was the
                                                    `claimed` flag under the class lock
     cb gate       (two atomics per command buffer) the pass touches a command buffer's _parts only between enter and
                                                    leave; nvmtlFinishExecution sets fin and waits for leave first
     surface lock  (os_unfair_lock, leaf)          the pending surface-write map (was the class lock too)

   Everything here is plain C so tools can test it without the plugin (user/tests/metal/plock_model.c). */
#ifndef NVMTL_PLOCK_H
#define NVMTL_PLOCK_H
#include <os/lock.h>
#include <sched.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

/* the build default; NVMTL_LOCK_V2=0/1 in a process's own environment overrides it for that process */
#ifndef NVMTL_LOCK_V2_DEFAULT
#define NVMTL_LOCK_V2_DEFAULT 0
#endif

/* Pure rule, testable: e is getenv("NVMTL_LOCK_V2"), confset getenv("NVMTL_CONF_SET") (the keys the conf file put into
   this process's environment, nvmtl_conf_knobs). Only the process's own environment counts: a conf line must not switch
   WindowServer (and every other Metal process) onto the new locking at once. */
int nvmtl_lock_v2(void);   /* the process's answer (NVMTLEventSync.m), read once */
static inline int nvmtl_plock_rule(const char *e, const char *confset)
{
    if (e && confset) {
        for (const char *p = strstr(confset, "NVMTL_LOCK_V2="); p; p = strstr(p + 1, "NVMTL_LOCK_V2="))
            if (p == confset || p[-1] == ';') { e = NULL; break; }   /* the value came from the conf file */
    }
    if (e && (e[0] == '0' || e[0] == '1') && !e[1]) return e[0] == '1';
    return NVMTL_LOCK_V2_DEFAULT;
}

static inline void nvmtl_plock_backoff(unsigned spin)
{
    if (spin < 64) {
#if defined(__x86_64__) || defined(__i386__)
        __builtin_ia32_pause();
#elif defined(__arm64__) || defined(__aarch64__)
        __asm__ __volatile__("yield");
#endif
    } else if (spin < 2048) sched_yield();
    else usleep(50);
}

/* The state lock's sections are a few hundred nanoseconds: a short spin on trylock first, so a brush between the
   committing thread and the worker does not become a kernel wait and wake (each a syscall: __ulock_wait2 /
   __ulock_wake were most of the class lock's cost in the cbcost sample). */
static inline void nvmtl_plock_lock(os_unfair_lock *l)
{
    for (unsigned i = 0; i < 128; i++) {
        if (os_unfair_lock_trylock(l)) return;
#if defined(__x86_64__) || defined(__i386__)
        __builtin_ia32_pause();
#elif defined(__arm64__) || defined(__aarch64__)
        __asm__ __volatile__("yield");
#endif
    }
    os_unfair_lock_lock(l);
}

/* Part hand-off. FREE: nobody has it. SUBMITTING: the submit-ahead pass is working on it (submit, empty retire, event
   fold). AHEAD: the pass is done with it (inflight / aheadFailed / aheadEmpty / waitFolded say what it did). WORKER: the
   execution worker took it to run it itself; the pass stops at it. Every field the pass writes is written before the
   release store of AHEAD, and the worker reads them after its acquire. */
enum { NVMTL_PART_FREE = 0, NVMTL_PART_SUBMITTING = 1, NVMTL_PART_AHEAD = 2, NVMTL_PART_WORKER = 3 };

/* the pass: FREE -> SUBMITTING. Returns the state it found (FREE: the part is the caller's until nvmtl_part_release). */
static inline int nvmtl_part_take(int *st)
{
    int s = NVMTL_PART_FREE;
    if (__atomic_compare_exchange_n(st, &s, NVMTL_PART_SUBMITTING, 0, __ATOMIC_ACQ_REL, __ATOMIC_ACQUIRE)) return NVMTL_PART_FREE;
    return s;
}
/* the pass lets go: AHEAD when it did something with the part, FREE when it left it as it was */
static inline void nvmtl_part_release(int *st, int to) { __atomic_store_n(st, to, __ATOMIC_RELEASE); }
/* the worker: WORKER when it took a free part (it runs it), AHEAD when the pass dealt with it first. A part the pass is
   in the middle of (one vkQueueSubmit) is waited for: the pass never waits for the worker, so this cannot deadlock. */
static inline int nvmtl_part_claim(int *st)
{
    for (unsigned spin = 0;; spin++) {
        int s = __atomic_load_n(st, __ATOMIC_ACQUIRE);
        if (s == NVMTL_PART_FREE) {
            if (__atomic_compare_exchange_n(st, &s, NVMTL_PART_WORKER, 0, __ATOMIC_ACQ_REL, __ATOMIC_ACQUIRE)) return NVMTL_PART_WORKER;
            continue;
        }
        if (s == NVMTL_PART_SUBMITTING) { nvmtl_plock_backoff(spin); continue; }
        return s;
    }
}
/* the worker gives a part back (an event wait not yet signalled): the pass may fold it later */
static inline void nvmtl_part_unclaim(int *st) { __atomic_store_n(st, NVMTL_PART_FREE, __ATOMIC_RELEASE); }

/* Command-buffer gate (Dekker, both sides sequentially consistent): either the pass sees fin and keeps out, or the
   finishing worker sees busy and waits for leave. Only one pass runs at a time (the ahead lock), so busy is 0 or 1. */
static inline int nvmtl_cb_enter(int *busy, const int *fin)
{
    __atomic_store_n(busy, 1, __ATOMIC_SEQ_CST);
    if (__atomic_load_n(fin, __ATOMIC_SEQ_CST)) { __atomic_store_n(busy, 0, __ATOMIC_RELEASE); return 0; }
    return 1;
}
static inline void nvmtl_cb_leave(int *busy) { __atomic_store_n(busy, 0, __ATOMIC_RELEASE); }
static inline void nvmtl_cb_finish_gate(const int *busy, int *fin)
{
    __atomic_store_n(fin, 1, __ATOMIC_SEQ_CST);
    for (unsigned spin = 0; __atomic_load_n(busy, __ATOMIC_SEQ_CST); spin++) nvmtl_plock_backoff(spin);
}

/* Combiner: whoever gets the lock runs the pass, again while someone asked for it in the meantime (at most max_rounds
   passes per call); whoever finds it held only asks. The holder re-checks after unlocking, so no request is lost
   between its last check and the unlock. A pass that asks for itself (a commit from inside a pass) only marks dirty. */
typedef struct { os_unfair_lock lock; int dirty; } nvmtl_combiner;
#define NVMTL_COMBINER_INIT { OS_UNFAIR_LOCK_INIT, 0 }
static __thread const nvmtl_combiner *nvmtl_comb_running;
/* returns the passes this call ran */
static inline unsigned nvmtl_combine(nvmtl_combiner *c, void (*pass)(void *), void *ctx, unsigned max_rounds)
{
    __atomic_store_n(&c->dirty, 1, __ATOMIC_SEQ_CST);
    if (nvmtl_comb_running == c) return 0;
    unsigned rounds = 0;
    while (rounds < max_rounds) {
        if (!os_unfair_lock_trylock(&c->lock)) return rounds;   /* the holder sees dirty and runs again */
        nvmtl_comb_running = c;
        while (rounds < max_rounds && __atomic_exchange_n(&c->dirty, 0, __ATOMIC_SEQ_CST)) { pass(ctx); rounds++; }
        nvmtl_comb_running = NULL;
        os_unfair_lock_unlock(&c->lock);
        if (!__atomic_load_n(&c->dirty, __ATOMIC_SEQ_CST)) break;
    }
    return rounds;
}
#endif
