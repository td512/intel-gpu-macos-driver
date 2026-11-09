// SPDX-License-Identifier: MIT
// plock_model: a stress test of the NVMTL_LOCK_V2 hand-off primitives (nullmoth/plugin/nvmtl_plock.h) in a model of the
// plugin's commit / submit-ahead / execution-worker structure, without Metal or a GPU (runs on any Mac).
//
// What is the plugin's own code: nvmtl_plock.h (part take/release/claim/unclaim, the command-buffer gate, the combiner,
// the env rule). What is modelled after NVMTLEventSync.m: the state lock over queues / pending / generation / pumping,
// the pass (per queue, in commit order, stop at the first command buffer that holds the queue back), the worker (queue
// heads only, finish gate, completion under the state lock, stop on no progress with an unchanged generation).
//
// Checked: every part reaches the "GPU" exactly once; per queue, parts reach it in commit order (cb, part); completions
// per queue in commit order; the pass never works inside a finished command buffer; nothing hangs (watchdog); all
// command buffers complete. Build and run (here, or anywhere):
//   clang -O2 -Wall -o plock_model plock_model.c && ./plock_model [seconds]
//   clang -O1 -g -fsanitize=thread -o plock_model_tsan plock_model.c && ./plock_model_tsan 5
//   clang -O1 -g -fsanitize=address -o plock_model_asan plock_model.c && ./plock_model_asan 5
#include <dispatch/dispatch.h>
#include <pthread.h>
#include <stdatomic.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <unistd.h>
#include "../../../nullmoth/plugin/nvmtl_plock.h"

int nvmtl_lock_v2(void) { return 1; }

enum { NQ = 4, NPROD = 6, MAXPARTS = 4, CAP = 48, PERQ = 48 };

typedef struct cb {
    int q; uint64_t seq; int nparts;
    int pstate[MAXPARTS];            // NVMTL_PART_*
    int submitted[MAXPARTS];         // times this part reached the "GPU"
    int unclaimed[MAXPARTS];         // the worker gave it back once (an event wait not yet signalled)
    int busy, fin;                   // the gate
    _Atomic int finished;            // set by the worker after the gate: the pass must never see it inside
    unsigned nextSubmit;             // the pass's (one pass at a time: the combiner)
    unsigned nextPart;               // the worker's, read by the pass (acquire)
    int allAhead;
    int marking;                     // between the two commit sections: the pass refuses it (acquire/release)
    int pending;                     // in the pending list (state lock): the worker may advance it
    _Atomic int refs;
    struct cb *next;                 // queue list (state lock)
} cb_t;

static os_unfair_lock gState = OS_UNFAIR_LOCK_INIT;   // queues' lists, pending count, generation, pumping
static nvmtl_combiner gAhead = NVMTL_COMBINER_INIT;
static struct { cb_t *head, *tail; uint64_t committed; uint64_t completed; } gQ[NQ];
static uint64_t gGeneration; static int gPumping; static unsigned gPending;
static dispatch_queue_t gWorkerQ;
static dispatch_semaphore_t gCap[NQ];
static pthread_mutex_t gCommitLock[NQ];                // the order of commits into one queue from several threads

static pthread_mutex_t gGpuLock = PTHREAD_MUTEX_INITIALIZER;   // nvmtl_submit_mutex + the one VkQueue
static struct { uint64_t seq; int part, nparts; } gGpuLast[NQ];  // the last part submitted per queue
static _Atomic uint64_t gErrors, gSubmits, gAheadSubmits, gWorkerSubmits, gCompleted, gPasses, gUnclaims;
static _Atomic int gStop;
static _Atomic uint64_t gProgressTick;

#define FAIL(...) do { atomic_fetch_add(&gErrors, 1); fprintf(stderr, "FAIL: " __VA_ARGS__); fputc('\n', stderr); } while (0)

static unsigned rnd(unsigned *s) { *s = *s * 1103515245u + 12345u; return (*s >> 16) & 0x7fff; }
static void cb_release(cb_t *c) { if (atomic_fetch_sub(&c->refs, 1) == 1) { memset(c, 0xdb, sizeof *c); free(c); } }

static void gpu_submit(cb_t *c, unsigned part, int ahead) {
    pthread_mutex_lock(&gGpuLock);
    // exactly the next part of the queue in commit order: (seq, part + 1) or (seq + 1, 0)
    __typeof__(gGpuLast[0]) *last = &gGpuLast[c->q];
    const int want_next_cb = last->part + 1 >= last->nparts;
    if (want_next_cb ? (c->seq != last->seq + 1 || part != 0) : (c->seq != last->seq || (int)part != last->part + 1))
        FAIL("queue %d: part (%llu,%u) submitted after (%llu,%d of %d)", c->q, (unsigned long long)c->seq, part,
             (unsigned long long)last->seq, last->part, last->nparts);
    last->seq = c->seq; last->part = (int)part; last->nparts = c->nparts;
    const int times = ++c->submitted[part];
    pthread_mutex_unlock(&gGpuLock);
    if (times != 1) FAIL("queue %d cb %llu part %u submitted %d times", c->q, (unsigned long long)c->seq, part, c->submitted[part]);
    atomic_fetch_add(&gSubmits, 1); atomic_fetch_add(ahead ? &gAheadSubmits : &gWorkerSubmits, 1);
}

// the pass for one command buffer (nvmtlSubmitAheadV2): YES when nothing of it holds the queue back
static int cb_submit_ahead(cb_t *c, unsigned *seed) {
    if (!nvmtl_cb_enter(&c->busy, &c->fin)) return 1;
    int all = 1;
    if (__atomic_load_n(&c->marking, __ATOMIC_ACQUIRE)) { nvmtl_cb_leave(&c->busy); return 0; }
    const unsigned done = __atomic_load_n(&c->nextPart, __ATOMIC_ACQUIRE);
    if (c->nextSubmit < done) c->nextSubmit = done;
    while (c->nextSubmit < (unsigned)c->nparts) {
        if (atomic_load(&c->finished)) FAIL("pass inside a finished command buffer");
        if (rnd(seed) % 10 == 0) { all = 0; break; }   // the in-flight cap, host copies, an unpromised event wait
        const unsigned k = c->nextSubmit;
        const int was = nvmtl_part_take(&c->pstate[k]);
        if (was == NVMTL_PART_AHEAD) { c->nextSubmit++; continue; }
        if (was != NVMTL_PART_FREE) { all = 0; break; }   // the worker runs it
        if (rnd(seed) % 4 == 0) sched_yield();            // a slow vkQueueSubmit: the worker spins on SUBMITTING
        gpu_submit(c, k, 1);
        nvmtl_part_release(&c->pstate[k], NVMTL_PART_AHEAD);
        c->nextSubmit++;
    }
    if (all) __atomic_store_n(&c->allAhead, 1, __ATOMIC_RELAXED);
    nvmtl_cb_leave(&c->busy);
    return all;
}
static void pass(void *ctx) {
    (void)ctx;
    static __thread unsigned seed = 1;
    if (seed == 1) seed = (unsigned)(uintptr_t)pthread_self();
    cb_t *list[NQ * PERQ + NQ]; unsigned n = 0;
    nvmtl_plock_lock(&gState);
    for (int q = 0; q < NQ; q++) {
        unsigned per = 0;
        for (cb_t *c = gQ[q].head; c && per < PERQ; c = c->next) {
            if (__atomic_load_n(&c->allAhead, __ATOMIC_RELAXED)) continue;
            atomic_fetch_add(&c->refs, 1); list[n++] = c; per++;
        }
        list[n++] = NULL;
    }
    os_unfair_lock_unlock(&gState);
    int stop = 0;
    for (unsigned i = 0; i < n; i++) {
        if (!list[i]) { stop = 0; continue; }
        if (!stop && !cb_submit_ahead(list[i], &seed)) stop = 1;
        cb_release(list[i]);
    }
    atomic_fetch_add(&gPasses, 1);
}

// the worker: nvmtlAdvancePart for a queue head; returns progress
static int advance(cb_t *c, unsigned *seed) {
    const unsigned k = c->nextPart;
    if (k < (unsigned)c->nparts) {
        const int how = nvmtl_part_claim(&c->pstate[k]);
        if (how == NVMTL_PART_WORKER) {
            if (!c->unclaimed[k] && rnd(seed) % 8 == 0) { c->unclaimed[k] = 1; atomic_fetch_add(&gUnclaims, 1); nvmtl_part_unclaim(&c->pstate[k]); return 0; }
            gpu_submit(c, k, 0);
        } else if (how != NVMTL_PART_AHEAD) FAIL("claim returned %d", how);
        if (c->submitted[k] != 1) FAIL("queue %d cb %llu part %u completed with %d submissions", c->q, (unsigned long long)c->seq, k, c->submitted[k]);
        __atomic_store_n(&c->nextPart, k + 1, __ATOMIC_RELEASE);
        if (k + 1 < (unsigned)c->nparts) return 1;
    }
    nvmtl_cb_finish_gate(&c->busy, &c->fin);
    atomic_store(&c->finished, 1);
    return 2;   // done
}
static void worker(void *ctx) {
    (void)ctx;
    unsigned seed = 7;
    for (;;) {
        nvmtl_combine(&gAhead, pass, NULL, 8);
        cb_t *heads[NQ]; unsigned nh = 0; uint64_t generation;
        nvmtl_plock_lock(&gState);
        generation = gGeneration;
        for (int q = 0; q < NQ; q++) if (gQ[q].head && gQ[q].head->pending) { atomic_fetch_add(&gQ[q].head->refs, 1); heads[nh++] = gQ[q].head; }
        os_unfair_lock_unlock(&gState);
        int progress = 0;
        for (unsigned i = 0; i < nh; i++) {
            cb_t *c = heads[i];
            const int r = advance(c, &seed);
            if (r) progress = 1;
            if (r == 2) {
                nvmtl_plock_lock(&gState);
                if (gQ[c->q].head != c) FAIL("queue %d: completed cb %llu is not the head", c->q, (unsigned long long)c->seq);
                gQ[c->q].head = c->next; if (!gQ[c->q].head) gQ[c->q].tail = NULL;
                if (c->seq != gQ[c->q].completed + 1) FAIL("queue %d: completion %llu after %llu", c->q, (unsigned long long)c->seq, (unsigned long long)gQ[c->q].completed);
                gQ[c->q].completed = c->seq; gPending--;
                os_unfair_lock_unlock(&gState);
                dispatch_semaphore_signal(gCap[c->q]);
                atomic_fetch_add(&gCompleted, 1); atomic_store(&gProgressTick, atomic_load(&gCompleted));
                cb_release(c);   // the list's reference
            }
            cb_release(c);
        }
        if (progress) continue;
        nvmtl_plock_lock(&gState);
        const int quit = generation == gGeneration;
        if (quit) gPumping = 0;
        os_unfair_lock_unlock(&gState);
        if (quit) return;
    }
}
static void pump(void) {
    nvmtl_plock_lock(&gState);
    if (!gPending) { os_unfair_lock_unlock(&gState); return; }
    ++gGeneration;
    const int start = !gPumping; if (start) gPumping = 1;
    os_unfair_lock_unlock(&gState);
    nvmtl_combine(&gAhead, pass, NULL, 8);
    if (start) dispatch_async_f(gWorkerQ, NULL, worker);
}
static void *producer(void *arg) {
    const int id = (int)(intptr_t)arg; unsigned seed = 1234u + (unsigned)id * 7919u;
    while (!atomic_load(&gStop)) {
        const int q = id < NQ ? id : (int)(rnd(&seed) % NQ);   // the first NQ producers own a queue, the rest share
        dispatch_semaphore_wait(gCap[q], DISPATCH_TIME_FOREVER);
        cb_t *c = calloc(1, sizeof *c);
        c->q = q; c->nparts = 1 + (int)(rnd(&seed) % MAXPARTS); atomic_store(&c->refs, 1);
        pthread_mutex_lock(&gCommitLock[q]);   // commit section 1: the queue's place, committed, marking on
        nvmtl_plock_lock(&gState);
        c->seq = ++gQ[q].committed;
        if (gQ[q].tail) gQ[q].tail->next = c; else gQ[q].head = c;
        gQ[q].tail = c;
        __atomic_store_n(&c->marking, 1, __ATOMIC_RELAXED);
        os_unfair_lock_unlock(&gState);
        pthread_mutex_unlock(&gCommitLock[q]);
        if (rnd(&seed) % 4 == 0) sched_yield();   // the seal and the kernel marks, outside any lock
        nvmtl_plock_lock(&gState);            // section 2: pending, marking off
        c->pending = 1; gPending++;
        __atomic_store_n(&c->marking, 0, __ATOMIC_RELEASE);
        os_unfair_lock_unlock(&gState);
        pump();
        if (rnd(&seed) % 16 == 0) usleep(rnd(&seed) % 50);
    }
    return NULL;
}
static void rule_tests(void) {
    struct { const char *e, *conf; int want; } t[] = {
        { NULL, NULL, NVMTL_LOCK_V2_DEFAULT }, { "1", NULL, 1 }, { "0", NULL, 0 }, { "1", "NVMTL_FOO=1", 1 },
        { "1", "NVMTL_LOCK_V2=1", NVMTL_LOCK_V2_DEFAULT }, { "1", "NVMTL_X=2;NVMTL_LOCK_V2=1", NVMTL_LOCK_V2_DEFAULT },
        { "1", "XNVMTL_LOCK_V2=1", 1 }, { "yes", NULL, NVMTL_LOCK_V2_DEFAULT }, { "", NULL, NVMTL_LOCK_V2_DEFAULT },
    };
    for (unsigned i = 0; i < sizeof t / sizeof *t; i++)
        if (nvmtl_plock_rule(t[i].e, t[i].conf) != t[i].want) FAIL("env rule %u (%s, %s)", i, t[i].e ? t[i].e : "unset", t[i].conf ? t[i].conf : "unset");
}
int main(int argc, char **argv) {
    const int secs = argc > 1 ? atoi(argv[1]) : 10;
    rule_tests();
    for (int q = 0; q < NQ; q++) gGpuLast[q].nparts = 0, gGpuLast[q].part = -1;
    gWorkerQ = dispatch_queue_create("model.execution", DISPATCH_QUEUE_SERIAL);
    for (int q = 0; q < NQ; q++) { gCap[q] = dispatch_semaphore_create(CAP); pthread_mutex_init(&gCommitLock[q], NULL); }
    pthread_t th[NPROD];
    for (int i = 0; i < NPROD; i++) pthread_create(&th[i], NULL, producer, (void *)(intptr_t)i);
    uint64_t last = 0; int still = 0;
    for (int s = 0; s < secs * 10; s++) {
        usleep(100000);
        const uint64_t now = atomic_load(&gProgressTick);
        if (now == last) { if (++still >= 30) { FAIL("no completion for 3 s - a hang"); break; } } else still = 0;
        last = now;
    }
    atomic_store(&gStop, 1);
    for (int q = 0; q < NQ; q++) for (int k = 0; k < NPROD; k++) dispatch_semaphore_signal(gCap[q]);   // unblock producers
    for (int i = 0; i < NPROD; i++) pthread_join(th[i], NULL);
    for (int w = 0; w < 300; w++) {   // drain: everything committed must complete
        nvmtl_plock_lock(&gState); const unsigned p = gPending; os_unfair_lock_unlock(&gState);
        if (!p) break;
        pump(); usleep(10000);
        if (w == 299) FAIL("%u command buffers never completed", p);
    }
    uint64_t committed = 0; for (int q = 0; q < NQ; q++) committed += gQ[q].committed;
    if (committed != atomic_load(&gCompleted)) FAIL("committed %llu, completed %llu", (unsigned long long)committed, (unsigned long long)atomic_load(&gCompleted));
    printf("plock_model: %llu command buffers, %llu parts (%llu ahead, %llu by the worker), %llu passes, %llu unclaims: %s (%llu errors)\n",
           (unsigned long long)atomic_load(&gCompleted), (unsigned long long)atomic_load(&gSubmits), (unsigned long long)atomic_load(&gAheadSubmits),
           (unsigned long long)atomic_load(&gWorkerSubmits), (unsigned long long)atomic_load(&gPasses), (unsigned long long)atomic_load(&gUnclaims),
           atomic_load(&gErrors) ? "FAILED" : "PASS", (unsigned long long)atomic_load(&gErrors));
    return atomic_load(&gErrors) ? 1 : 0;
}
