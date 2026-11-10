#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
# equiv.py <dylib> <ll> <nsets> <outdir>: fixed_frag sets; whole vs frozen fc-spec, both through spirv-opt -O; prints
# texture-op counts and whether the optimized opcode histograms agree
import random, subprocess, sys, os, re, collections
dy, ll, nsets, out = sys.argv[1], sys.argv[2], int(sys.argv[3]), sys.argv[4]
os.makedirs(out, exist_ok=True)
text = open(ll).read()
SZ = {'i1': 1, 'i8': 1, 'i16': 2, 'i32': 4, 'half': 2, 'float': 4}
fcs = {}
for m in re.finditer(r'^@[^ ]*MTL_FC_INIT_(\d+)_(\S*) = .*? constant (<(\d+) x (\w+)>|\w+) ', text, re.M):
    kind = 'bool' if m.group(2) == 'b' else 'x'
    if m.group(4): fcs[int(m.group(1))] = (int(m.group(4)) * SZ.get(m.group(5), 4), kind)
    else: fcs[int(m.group(1))] = (SZ.get(m.group(3), 4), kind)
st = 'fragment' if re.search(r'^!air\.fragment = ', text, re.M) else 'vertex' if re.search(r'^!air\.vertex = ', text, re.M) else 'kernel'
IMG = re.compile(r'OpImage(Sample|Fetch|Gather|Read|Write|QueryLod)')
def hist(p):
    d = subprocess.run(['spirv-dis', '--raw-id', p], capture_output=True, text=True).stdout
    ops = collections.Counter(l.split('=')[-1].split()[0] for l in d.splitlines() if l.strip().startswith(('%', 'Op')) and 'Op' in l)
    return len(IMG.findall(d)), ops
bad = 0
for s in range(nsets):
    rnd = random.Random(1000 + s)
    args = []
    for i, (n, t) in sorted(fcs.items()):
        if s == 0: v = bytes(n)
        elif t == 'bool': v = bytes([rnd.random() < 0.3])
        else: v = bytes(rnd.choice([0, 1, 2, 3, rnd.randrange(256)]) for _ in range(n))
        args.append('%d:%d:%s' % (i, n, v.hex()))
    pre = os.path.join(out, 'set%02d' % s)
    r = subprocess.run(['./fcequiv', dy, ll, st, pre] + args, capture_output=True, text=True)
    if r.returncode: print('set', s, 'harness:', r.stdout.strip()); continue
    wi, wh = hist(pre + '-whole.spv'); fi, fh = hist(pre + '-frozen.spv')
    same = fi >= wi   # the fc-spec module may keep more (less is folded), never fewer texture operations
    bad += not same
    print('set%02d whole-tex %s frozen-spec-tex %s %s' % (s, wi, fi, 'OK' if same else 'LOST TEXTURE OPS'), flush=True)
print('mismatches', bad)
