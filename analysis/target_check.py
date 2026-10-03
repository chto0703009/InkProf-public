# Copyright (c) 2026 Christer Törnkvist.
# SPDX-License-Identifier: GPL-3.0-or-later
# InkProf is free software under GNU GPL version 3 or later.
# Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
"""Diagnostic comparison with TI2 estimates, never profile validation."""
import numpy as np
import colour


def check_target(chart, measurement, xyz100, threshold=20.0):
    if not np.isfinite(threshold) or threshold <= 0:
        raise ValueError('Target warning threshold must be positive and finite.')
    result = {'schemaVersion': 1, 'purpose': 'Rough check against TI2 estimates; not profile accuracy',
              'thresholdDeltaE00': float(threshold), 'available': False}
    tables = chart.get('exchangeTables', [])
    if isinstance(tables, dict): tables = [tables]
    table = next((t for t in tables if t['signature'] == 'CTI2'), None)
    fields = ['SAMPLE_ID', 'SAMPLE_LOC', 'RGB_R', 'RGB_G', 'RGB_B', 'XYZ_X', 'XYZ_Y', 'XYZ_Z']
    if not table or not all(f in table['fields'] for f in fields):
        return dict(result, reason='TI2 XYZ estimates are unavailable; RGB alone is not a colour reference.')
    meta = table['metadata']
    if isinstance(meta, dict): meta = [meta]
    whites = [x['tokens'][1] for x in meta if x['tokens'][0] == 'APPROX_WHITE_POINT']
    if len(whites) != 1:
        return dict(result, reason='No unique APPROX_WHITE_POINT in TI2; reference white is not assumed.')
    white = np.fromstring(whites[0], sep=' ')
    if white.shape != (3,) or not np.isfinite(white).all() or np.any(white <= 0):
        raise ValueError('Invalid TI2 approximate white point.')
    rows = table['rows']
    if isinstance(rows, dict): rows = [rows]
    lookup = {}
    for row in rows:
        r = dict(zip(table['fields'], row['values']))
        key = (r['SAMPLE_ID'], r['SAMPLE_LOC'])
        if key in lookup: raise ValueError('Duplicate TI2 identity.')
        lookup[key] = r
    refs = []
    for i, key in enumerate(zip(measurement['ids'], measurement['locations'])):
        if key not in lookup: raise ValueError('Measured patch missing from TI2.')
        r = lookup[key]
        rgb = np.array([float(r[f'RGB_{c}']) for c in 'RGB'])
        if not np.allclose(rgb, measurement['rgbPercent'][i], atol=1e-4, rtol=0):
            raise ValueError('RGB differs between TI2 and measurement.')
        refs.append([float(r[f'XYZ_{c}']) for c in 'XYZ'])
    refs = np.asarray(refs)
    if not np.isfinite(refs).all() or np.any(refs < 0): raise ValueError('Invalid TI2 XYZ estimates.')
    wp = colour.CCS_ILLUMINANTS['CIE 1931 2 Degree Standard Observer']['D50']
    white50 = colour.xy_to_XYZ(wp)
    # Explicit heuristic: approximate white is treated as the estimate's source white.
    adapted = colour.adaptation.chromatic_adaptation_VonKries(refs/100, white/100, white50, transform='Bradford')
    expected_lab = colour.XYZ_to_Lab(adapted, wp)
    measured_lab = colour.XYZ_to_Lab(np.asarray(xyz100)/100, wp)
    de = colour.difference.delta_E_CIE2000(measured_lab, expected_lab)
    return dict(result, available=True, referenceWhiteXYZ100=white.tolist(),
                assumption='TI2 XYZ uses scale 100; APPROX_WHITE_POINT treated as source white and Bradford-adapted to D50. Diagnostic assumption, not a certified reference.',
                expectedLab=expected_lab.tolist(), patchDeltaE00=de.tolist(), flagged=(de > threshold).tolist(),
                flaggedCount=int(np.sum(de > threshold)), maxDeltaE00=float(np.max(de)),
                identities=[{'id':i,'location':l} for i,l in zip(measurement['ids'],measurement['locations'])])
