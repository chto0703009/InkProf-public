# Copyright (c) 2026 Christer Törnkvist.
# SPDX-License-Identifier: GPL-3.0-or-later
# InkProf is free software under GNU GPL version 3 or later.
# Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
"""Read reference colour sets for profile tests (C2).

Supported inputs
  * Lab tables: tab/space separated text with a header row naming the patch
    column (Patch, SAMPLE_ID, SAMPLE_NAME, ID or Name) and LAB_L LAB_A LAB_B,
    e.g. a ColorChecker SG D50 Lab table; trailing note lines are ignored.
  * CGATS files (Argyll .cie/.ti2/.ti3, CGATS .txt) with LAB_L/A/B or XYZ_X/Y/Z
    (XYZ 0..100 is converted to Lab against ICC D50).
  * Device RGB sets: CGATS with RGB_R/G/B (TI1/TI2), percent 0..100.
Lab sets are reference colours to be reproduced through the profile's B2A.
RGB sets are printed as-is; their reference Lab is the profile's A2B prediction.
"""
import hashlib
import math
import re
from pathlib import Path

ICC_D50 = (96.42, 100.0, 82.49)
ID_COLUMNS = ('SAMPLE_ID', 'SAMPLE_NAME', 'PATCH', 'ID', 'NAME', 'SAMPLE_LOC')
TOKEN = re.compile(r'"[^"]*"|\S+')


def _xyz_to_lab(x, y, z):
    eps, kappa = 216 / 24389, 24389 / 27
    f = [v ** (1 / 3) if v > eps else (kappa * v + 16) / 116 for v in (x / ICC_D50[0], y / ICC_D50[1], z / ICC_D50[2])]
    return [116 * f[1] - 16, 500 * (f[0] - f[1]), 200 * (f[1] - f[2])]


def _table(text):
    """Return (fields, rows, notes) from CGATS or a delimited table."""
    lines = text.splitlines()
    marks = [k for k, line in enumerate(lines) if line.strip() in ('BEGIN_DATA_FORMAT', 'END_DATA_FORMAT', 'BEGIN_DATA', 'END_DATA')]
    if marks:
        def one(name):
            found = [k for k, line in enumerate(lines) if line.strip() == name]
            if len(found) != 1:
                raise ValueError(f'Expected exactly one {name}; multi-table CGATS is not supported here.')
            return found[0]
        f0, f1, d0, d1 = (one(n) for n in ('BEGIN_DATA_FORMAT', 'END_DATA_FORMAT', 'BEGIN_DATA', 'END_DATA'))
        fields = ' '.join(lines[f0 + 1:f1]).split()
        rows = [[t.strip('"') for t in TOKEN.findall(line)] for line in lines[d0 + 1:d1] if line.strip() and not line.lstrip().startswith('#')]
        notes = [line.strip() for line in lines[:f0] if line.strip()]
        return fields, rows, notes
    rows, fields, notes = [], None, []
    for line in lines:
        cells = [c.strip() for c in (line.split('\t') if '\t' in line else line.split())]
        cells = [c for c in cells if c != '']
        if fields is None:
            if any(c.upper() in ('LAB_L', 'XYZ_X', 'RGB_R') for c in cells):
                fields = cells
            continue
        if not cells:
            continue
        if len(cells) == len(fields):
            rows.append(cells)
        else:
            notes.append(line.strip())
    if fields is None:
        raise ValueError('No header with LAB_L/A/B, XYZ_X/Y/Z or RGB_R/G/B was found.')
    return fields, rows, notes


def load(path):
    path = Path(path)
    raw = path.read_bytes()
    text = raw.decode('utf-8-sig', errors='strict') if raw[:3] == b'\xef\xbb\xbf' else raw.decode('latin-1')
    fields, rows, notes = _table(text)
    upper = [f.upper() for f in fields]
    if not rows:
        raise ValueError('The reference set contains no data rows.')
    if any(u.startswith('CMYK_') for u in upper):
        raise ValueError('CMYK reference sets are not supported for RGB printer profiles.')
    id_col = next((upper.index(c) for c in ID_COLUMNS if c in upper), None)
    def column(name):
        return upper.index(name) if name in upper else None
    lab_cols = [column(c) for c in ('LAB_L', 'LAB_A', 'LAB_B')]
    xyz_cols = [column(c) for c in ('XYZ_X', 'XYZ_Y', 'XYZ_Z')]
    rgb_cols = [column(c) for c in ('RGB_R', 'RGB_G', 'RGB_B')]
    names, values = [], []
    if all(c is not None for c in lab_cols) or all(c is not None for c in xyz_cols):
        kind = 'lab'
        basis = 'LAB columns' if all(c is not None for c in lab_cols) else 'XYZ columns converted to Lab (ICC D50, XYZ 0..100)'
    elif all(c is not None for c in rgb_cols):
        kind, basis = 'rgb', 'device RGB percent 0..100'
    else:
        raise ValueError('Reference set needs LAB_L/A/B, XYZ_X/Y/Z or RGB_R/G/B columns.')
    for k, row in enumerate(rows, 1):
        name = row[id_col] if id_col is not None else str(k)
        try:
            if kind == 'lab' and all(c is not None for c in lab_cols):
                v = [float(row[c]) for c in lab_cols]
            elif kind == 'lab':
                v = _xyz_to_lab(*[float(row[c]) for c in xyz_cols])
            else:
                v = [float(row[c]) for c in rgb_cols]
        except (ValueError, IndexError) as exc:
            raise ValueError(f'Invalid number in reference row {k} ({name}).') from exc
        if not all(math.isfinite(x) for x in v):
            raise ValueError(f'Non-finite value in reference row {k} ({name}).')
        if kind == 'lab' and not (0 <= v[0] <= 100 and abs(v[1]) <= 200 and abs(v[2]) <= 200):
            raise ValueError(f'Lab out of range in row {k} ({name}).')
        if kind == 'rgb' and not all(-1e-9 <= x <= 100 + 1e-9 for x in v):
            raise ValueError(f'RGB must be 0..100 percent in row {k} ({name}).')
        names.append(name); values.append(v)
    if len(set(names)) != len(names):
        raise ValueError('Patch names in the reference set are not unique.')
    return dict(kind=kind, basis=basis, names=names, values=values, count=len(names), fileName=path.name,
                sha256=hashlib.sha256(raw).hexdigest(), notes=notes[:20])
