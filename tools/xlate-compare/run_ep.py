#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
# run_ep.py <old.dylib> <new.dylib> <outdir> <ll>...: each function through every entry point with a few constant sets,
# old and new translator, and a list of the outputs that differ
import os, re, subprocess, sys, random, hashlib
old, new, out = sys.argv[1:4]
SIZES = {'i1': 1, 'i8': 1, 'i16': 2, 'i32': 4, 'i64': 8, 'half': 2, 'float': 4, 'double': 8}
def size_of(t):
    t = t.strip()
    m = re.match(r'<(\d+) x (\w+)>', t)
    if m: return int(m.group(1)) * SIZES.get(m.group(2), 4)
    return SIZES.get(t)
diffs = 0; total = 0
for ll in sys.argv[4:]:
    text = open(ll).read()
    st = 'kernel'
    if re.search(r'^!air\.fragment = ', text, re.M): st = 'fragment'
    elif re.search(r'^!air\.vertex = ', text, re.M): st = 'vertex'
    fcs = {}
    for m in re.finditer(r'^@[^ ]*MTL_FC_INIT_(\d+)_\S* = .*? constant (<[^>]+>|\w+) ', text, re.M):
        s = size_of(m.group(2))
        if s: fcs[int(m.group(1))] = s
    rnd = random.Random(hash(os.path.basename(ll)) & 0xffff)
    sets = [None] if not fcs else []
    if fcs:
        sets.append({i: '00' * s for i, s in fcs.items()})
        for _ in range(3):
            sets.append({i: ''.join('%02x' % (rnd.choice([0, 1, 2, 3, 0xff, rnd.randrange(256)]) if s > 1 else rnd.randrange(2)) for _ in range(s)) for i, s in fcs.items()})
    name = os.path.basename(ll)[:-3]
    for k, cs in enumerate(sets):
        args = [] if cs is None else ['%d:%d:%s' % (i, fcs[i], v) for i, v in sorted(cs.items())]
        res = {}
        for tag, dy in (('old', old), ('new', new)):
            d = os.path.join(out, name, str(k), tag); os.makedirs(d, exist_ok=True)
            subprocess.run(['./ep', dy, ll, st, d] + args, capture_output=True, timeout=600)
            res[tag] = {f: hashlib.sha256(open(os.path.join(d, f), 'rb').read()).hexdigest()[:12] for f in sorted(os.listdir(d))}
        total += 1
        bad = [f for f in sorted(set(res['old']) | set(res['new'])) if res['old'].get(f) != res['new'].get(f)]
        if bad:
            diffs += 1
            print('DIFF', name, k, ' '.join(bad), flush=True)
print('sets', total, 'with differences', diffs)
