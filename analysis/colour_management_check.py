# Copyright (c) 2026 Christer Törnkvist.
# SPDX-License-Identifier: GPL-3.0-or-later
# InkProf is free software under GNU GPL version 3 or later.
# Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
"""C3 diagnostic: was the C2 print colour-managed a second time?

A C2 TIFF already holds printer device RGB. If an application assigns a
working space (sRGB, Adobe RGB 1998) and converts to the printer profile, the
print shows those RGB values interpreted in that space instead of the desired
colours. This module simulates that chain with the printer profile (LittleCMS,
relative colorimetric, no BPC) and compares it with the measurement. It is a
heuristic warning, not proof: other print-chain faults can look similar.
"""
import numpy as np
import colour

D50 = colour.CCS_ILLUMINANTS['CIE 1931 2 Degree Standard Observer']['D50']
# Bradford-adapted D50 RGB->XYZ matrices (white Y = 1).
SPACES = {
    'sRGB': (np.array([[0.4360747, 0.3850649, 0.1430804],
                       [0.2225045, 0.7168786, 0.0606169],
                       [0.0139322, 0.0971045, 0.7141733]]),
             lambda v: np.where(v <= 0.04045, v / 12.92, ((v + 0.055) / 1.055) ** 2.4)),
    'Adobe RGB (1998)': (np.array([[0.6097559, 0.2052401, 0.1492240],
                                   [0.3111242, 0.6256560, 0.0632197],
                                   [0.0194811, 0.0608902, 0.7448387]]),
                         lambda v: v ** (563 / 256)),
}
MIN_DIRECT_MEAN = 3.0   # dE00; below this the print is close enough not to warn
RATIO = 0.6             # simulated chain must explain the measurement clearly better


def _lab_from_space(rgb, space):
    matrix, decode = SPACES[space]
    return colour.XYZ_to_Lab(decode(np.clip(rgb, 0, 1)) @ matrix.T, D50)


def _relative_to_absolute(rel_lab, scale):
    xyz = colour.Lab_to_XYZ(rel_lab, D50) * scale
    return colour.XYZ_to_Lab(xyz, D50)


def check(profile, reference, patches):
    """patches: C3 patch records (sampleId, role, measuredLab, deltaE00)."""
    by_id = {str(p['id']): p for p in reference['patches']}
    used = [p for p in patches if p['role'] not in ('repeat', 'paperwhite') and str(p['sampleId']) in by_id]
    if len(used) < 10:
        return dict(status='not-evaluated', reason='Fewer than 10 unique patches.')
    rgb = np.array([by_id[str(p['sampleId'])]['deviceRGB'] for p in used], dtype=float)
    measured = np.array([p['measuredLab'] for p in used], dtype=float)
    direct = np.array([p['deltaE00'] for p in used], dtype=float)
    try:
        from lcms_float import LittleCMS
        cmm = LittleCMS()
        # Relative -> absolute scale from the stored absolute A2B predictions.
        rel = cmm.transform(profile, rgb, 'f')
        absolute = np.array([by_id[str(p['sampleId'])]['predictedLabD50Absolute'] for p in used], dtype=float)
        ratio = colour.Lab_to_XYZ(absolute, D50) / np.maximum(colour.Lab_to_XYZ(rel, D50), 1e-6)
        scale = np.median(ratio[(rel[:, 0] > 20)], axis=0) if (rel[:, 0] > 20).sum() >= 5 else np.ones(3)
        spaces = {}
        for name in SPACES:
            source = _lab_from_space(rgb, name)
            device = np.clip(cmm.transform(profile, source, 'b'), 0, 1)
            simulated = _relative_to_absolute(cmm.transform(profile, device, 'f'), scale)
            d = colour.delta_E(simulated, measured, method='CIE 2000')
            spaces[name] = dict(mean=float(d.mean()), median=float(np.median(d)), p95=float(np.percentile(d, 95)))
    except Exception as exc:  # diagnostic only; never block C3
        return dict(status='unavailable', reason=f'{type(exc).__name__}: {exc}')
    best = min(spaces, key=lambda k: spaces[k]['mean'])
    direct_mean = float(direct.mean())
    suspected = direct_mean >= MIN_DIRECT_MEAN and spaces[best]['mean'] <= RATIO * direct_mean
    result = dict(status='evaluated', suspectedDoubleColourManagement=bool(suspected), patchCount=len(used),
                  directMeanDeltaE00=direct_mean, simulated=spaces, bestMatch=best,
                  method=('Device RGB interpreted as a working space, converted with the printer ICC (LittleCMS, relative '
                          'colorimetric, no BPC), predicted with A2B and compared with the measurement. Warning when the '
                          f'direct mean dE00 >= {MIN_DIRECT_MEAN} and the simulated chain has mean dE00 <= {RATIO} x direct.'),
                  caveat='Heuristic. Rendering intent, BPC and other print-chain faults (clogged nozzles, wrong media) can give similar patterns.')
    if suspected:
        result['message'] = (f'Suspected double colour management: the measurement matches the TIFF values treated as {best} '
                             f'and converted with the printer ICC (mean dE00 {spaces[best]["mean"]:.1f}) much better than the '
                             f'desired colours (mean dE00 {direct_mean:.1f}). Check that the application did not assign or convert '
                             'a profile (e.g. Photoshop assigning its working space to an untagged file) and that colour management was off.')
    return result
