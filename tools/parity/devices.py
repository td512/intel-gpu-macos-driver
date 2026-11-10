#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
"""The supported-device list against every copy of it in the repository.

data/platforms.json "supported" is the one list of the PCI devices (vendor 8086) this driver attaches to. The kexts,
the install scripts, the app and the Windows EFI tool each keep their own copy, in their own language and format; this
script reads each copy and fails when one differs from that list. No copy is generated: a new card is added to
data/platforms.json, then to each copy this script names (docs/design/DESIGN-platforms.md section 4).

  copies     each must list exactly the supported ids: IntelXe.kext and NMXAccel IOPCIMatch, install.sh (template and
             the filled copy) with its "untested" mark = not "tested", efi.sh, the app, the Windows tool, the kernel's
             platform test;
  kernel     the descriptor id array named by "kernel_ids" (xe_platform.cpp) holds every supported id;
  mentions   the files that describe the cards to people name every supported id and card.

  python3 tools/parity/devices.py           check; exit 1 on a difference
  python3 tools/parity/devices.py --list    the list itself, one device per line
Python stdlib only.
"""
import json, os, plistlib, re, sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))


def read(rel):
    with open(os.path.join(ROOT, rel), encoding='utf-8') as f:
        return f.read()


def one(rel, pattern, flags=0):
    """The first group of the only match of pattern in rel; raises when there is not exactly one."""
    m = re.findall(pattern, read(rel), flags)
    if len(m) != 1:
        raise ValueError('%d matches of %r (the check needs exactly one; update tools/parity/devices.py with the file)' % (len(m), pattern))
    return m[0]


def pci_match_ids(value):
    """IOPCIMatch / IOPCIPrimaryMatch '0xe20b8086 0xe20c8086' -> ['e20b', 'e20c']; a mask entry is an error."""
    ids = []
    for tok in value.split():
        m = re.fullmatch(r'0x([0-9a-fA-F]{4})8086', tok)
        if not m:
            raise ValueError('unexpected match entry %r' % tok)
        ids.append(m.group(1).lower())
    return ids


def plist_match(rel, personality):
    with open(os.path.join(ROOT, rel), 'rb') as f:
        p = plistlib.load(f)['IOKitPersonalities'][personality]
    return pci_match_ids(p.get('IOPCIMatch') or p['IOPCIPrimaryMatch'])


def c_ids(text):
    return [x.lower() for x in re.findall(r'0x([0-9a-fA-F]{4})', text)]


def install_cards(rel):
    """install.sh CARDS=("e20b B580" "e20c B570 untested") -> [(id, name, untested)]"""
    body = one(rel, r'^CARDS=\(([^)]*)\)$', re.M)
    out = []
    for e in re.findall(r'"([^"]*)"', body):
        f = e.split()
        out.append((f[0].lower(), f[1], f[2:] == ['untested']))
    return out


def copies(sup):
    """(where, ids found, extra problems) for each copy of the list."""
    want = [(d['id'], d['name'], not d['tested']) for d in sup['devices']]
    res = []

    def add(where, fn):
        try:
            ids, extra = fn()
        except (ValueError, KeyError, OSError) as e:
            ids, extra = None, [str(e)]
        res.append((where, ids, extra))

    # IntelXe's personality; XeProbe's matches every Intel device by mask ('0x00008086&0x0000ffff') and is not a copy
    add('kernel/IntelXe/build.py IntelXe IOPCIMatch',
        lambda: (pci_match_ids(one('kernel/IntelXe/build.py', r"IOProviderClass='IOPCIDevice',IOPCIMatch='([^'&]*)'")), []))
    add('nullmoth/kexts/NVRM/accel/Info-NMX-IntelXe.plist IOPCIPrimaryMatch',
        lambda: (plist_match('nullmoth/kexts/NVRM/accel/Info-NMX-IntelXe.plist', 'NMXAccel-IntelXe'), []))
    add('kernel/IntelXe/tests/platform_test.cpp kMatch',
        lambda: (c_ids(one('kernel/IntelXe/tests/platform_test.cpp', r'kMatch\[\] = \{([^}]*)\}')), []))
    for rel in ('release/templates/install.sh', 'release/install.sh'):
        def f(rel=rel):
            cards = install_cards(rel)
            extra = [] if cards == want else ['CARDS %r, expected %r (id, name, untested)' % (cards, want)]
            return [c[0] for c in cards], extra
        add(rel + ' CARDS', f)
    add('release/templates/efi.sh CARD_IDS',
        lambda: (one('release/templates/efi.sh', r'^CARD_IDS="([^"]*)"$', re.M).lower().split(), []))

    def app():
        body = one('app/Sources/Model.swift', r'^let supportedCards: \[\(id: String, name: String\)\] = \[(.*)\]$', re.M)
        cards = re.findall(r'\("([0-9a-fA-F]{4})", "([^"]*)"\)', body)
        extra = ['name %r for %s, expected "Intel Arc %s"' % (n, i, w[1]) for (i, n), w in zip(cards, want) if n != 'Intel Arc ' + w[1]]
        return [i.lower() for i, _ in cards], extra
    add('app/Sources/Model.swift supportedCards', app)
    add('windows/IntelXe-EFI.ps1 $cardIds',
        lambda: ([x.lower() for x in re.findall(r"'([0-9A-Fa-f]{4})'", one('windows/IntelXe-EFI.ps1', r'^\s*\$cardIds = @\(([^)]*)\)$', re.M))], []))
    return res


def kernel_problems(sup):
    src = read('kernel/IntelXe/xe_platform.cpp')
    arr = sup['kernel_ids']
    m = re.search(r'const uint16_t %s\[\] = \{([^}]*)\}' % re.escape(arr), src)
    if not m:
        return ['kernel/IntelXe/xe_platform.cpp: no id array %s' % arr]
    have = set(c_ids(m.group(1)))
    out = ['kernel/IntelXe/xe_platform.cpp %s lacks %s' % (arr, d['id']) for d in sup['devices'] if d['id'] not in have]
    if not re.search(r'entry\("[^"]*", [^,]*, XP_IDS\(%s\),' % re.escape(arr), src):
        out.append('kernel/IntelXe/xe_platform.cpp: no kXePlatforms entry uses %s' % arr)
    return out


# Files that describe the supported cards to people: each must name every id (any case) and card.
MENTIONS = [
    ('README.md', 'id name'), ('README.tr.md', 'id name'),
    ('release/templates/README-INSTALL.md', 'id name'), ('release/templates/README-INSTALL.tr.md', 'id name'),
    ('efi/README.md', 'id name'), ('tools/parity/platforms.py', 'id name'),
    ('kernel/IntelXe/IntelXe.cpp', 'model'),   # the "model" property per card
]


def mention_problems(sup):
    out = []
    for rel, what in MENTIONS:
        text = read(rel)
        for d in sup['devices']:
            for w in what.split():
                needle = d[w]
                found = needle.lower() in text.lower() if w == 'id' else needle in text
                if not found:
                    out.append('%s does not name %s (%s)' % (rel, needle, w))
    return out


def main():
    sup = json.loads(read('data/platforms.json'))['supported']
    ids = [d['id'] for d in sup['devices']]
    if '--list' in sys.argv[1:]:
        for d in sup['devices']:
            print('8086:%s  %s  %-26s %s' % (d['id'], d['name'], d['model'], 'tested' if d['tested'] else 'untested'))
        return 0
    bad = 0
    for where, got, extra in copies(sup):
        if got is not None and sorted(got) == sorted(ids) and len(got) == len(set(got)) and not extra:
            print('ok    %s: %s' % (where, ' '.join(got)))
            continue
        bad += 1
        why = extra or ['lists %s, data/platforms.json "supported" has %s' % (' '.join(got or []), ' '.join(ids))]
        print('FAIL  %s: %s' % (where, '; '.join(why)))
    for p in kernel_problems(sup) + mention_problems(sup):
        bad += 1
        print('FAIL  ' + p)
    if not bad:
        print('ok    kernel descriptor %s holds every id; %d files name every card' % (sup['kernel_ids'], len(MENTIONS)))
    print('devices: %d supported (%s), %d problem(s)' % (len(ids), ' '.join(ids), bad))
    return 1 if bad else 0


if __name__ == '__main__':
    sys.exit(main())
