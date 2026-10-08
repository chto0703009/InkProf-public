# Copyright (c) 2026 Christer Törnkvist.
# SPDX-License-Identifier: GPL-3.0-or-later
# InkProf is free software under GNU GPL version 3 or later.
# Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
"""Compare row remeasurement with parent XYZ in D50 Lab; no accuracy claim."""
import json, sys
from pathlib import Path
import numpy as np
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'profiles'))
from colour_math import xyz_to_lab, delta_e00


def compare(parent, candidate, request):
    old_map = np.asarray(parent['chartIndex']).reshape(-1)
    new_map = np.asarray(candidate['chartIndex']).reshape(-1)
    rows = []
    for local, index in enumerate(request['chartIndices'], 1):
        old = np.flatnonzero(old_map == index); new = np.flatnonzero(new_map == local)
        if not len(old) or not len(new):
            continue  # Padding need not be present in a paired mean.
        if len(old) != 1 or len(new) != 1:
            raise ValueError('Ambiguous row patch mapping.')
        a, b = int(old[0]), int(new[0])
        if str(candidate['data']['ids'][b]) == '0':
            continue
        old_lab = xyz_to_lab(np.asarray(parent['data']['xyz'][a])[None, :])[0]
        new_lab = xyz_to_lab(np.asarray(candidate['data']['xyz'][b])[None, :])[0]
        rows.append(dict(location=parent['data']['locations'][a], deltaE00=float(delta_e00(old_lab, new_lab)),
                         previousLab=old_lab.tolist(), newLab=new_lab.tolist()))
    if not rows:
        raise ValueError('No measured source patches on the selected row.')
    return dict(patches=rows, maxDeltaE00=max(r['deltaE00'] for r in rows),
                meanDeltaE00=float(np.mean([r['deltaE00'] for r in rows])),
                note='Change from previous measurements, using stored XYZ and ICC D50. Not profile accuracy.')


if __name__ == '__main__':
    a, b, q, out = map(Path, sys.argv[1:])
    r = compare(json.loads(a.read_text()), json.loads(b.read_text()), json.loads(q.read_text()))
    out.write_text(json.dumps(r, indent=2, allow_nan=False))
