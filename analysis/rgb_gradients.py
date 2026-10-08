# Copyright (c) 2026 Christer Törnkvist.
# SPDX-License-Identifier: GPL-3.0-or-later
# InkProf is free software under GNU GPL version 3 or later.
# Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
"""Device RGB ramps through final ICC A2B; numerical smoothness diagnostic."""
import argparse
import json
from pathlib import Path
import numpy as np
from sky_ramp import lookup, sha, stats, delta_e00

SAMPLES = 1025


def ramps(samples=SAMPLES):
    t = np.linspace(0, 1, samples)[:, None]
    endpoints = {
        'Neutral': ([0, 0, 0], [1, 1, 1]),
        'Red': ([0, 0, 0], [1, 0, 0]),
        'Green': ([0, 0, 0], [0, 1, 0]),
        'Blue': ([0, 0, 0], [0, 0, 1]),
        'Cyan': ([0, 0, 0], [0, 1, 1]),
        'Magenta': ([0, 0, 0], [1, 0, 1]),
        'Yellow': ([0, 0, 0], [1, 1, 0]),
        'Blue to white': ([0, 0, 1], [1, 1, 1]),
        'Dark blue to pale blue': ([0.05, 0.10, 0.35], [0.65, 0.80, 1]),
    }
    return {name: np.asarray(a) + t * (np.asarray(b) - a) for name, (a, b) in endpoints.items()}


def metrics(rgb, lab):
    lab = np.asarray(lab, dtype=float)
    steps = delta_e00(lab[:-1], lab[1:])
    second = np.linalg.norm(np.diff(lab, n=2, axis=0), axis=1)
    median = float(np.median(steps))
    k = int(np.argmax(second))
    dt = 1 / (len(lab) - 1)
    return dict(colourStepDeltaE00=stats(steps), labSecondDifference=stats(second),
                normalizedSecondDerivativeMax=float(second.max() / dt ** 2),
                colourStepMaxOverMedian=None if median < 1e-6 else float(steps.max() / median),
                worstAt=float((k + 1) * dt), worstRGB=np.asarray(rgb)[k + 1].tolist())


def run(profile, exe, out):
    profile, out = Path(profile), Path(out)
    if out.exists():
        raise ValueError('Output directory already exists.')
    digest = sha(profile)
    results = []
    for intent, label in (('r', 'relative colorimetric'), ('p', 'perceptual')):
        for name, rgb in ramps().items():
            lab = lookup(exe, profile, rgb, 'f', intent)
            results.append(dict(path=name, intent=label, rgb=rgb.tolist(), lab=lab.tolist(),
                                colourSteps=delta_e00(lab[:-1], lab[1:]).tolist(), metrics=metrics(rgb, lab)))
    if sha(profile) != digest:
        raise ValueError('Profile changed during check.')
    result = dict(schemaVersion=1, documentType='inkprof.rgb-gradient-check', profileSHA256=digest,
                  samples=SAMPLES, method='Uniform device RGB paths through ICC A2B using floating-point xicclu.',
                  caveat='Numerical diagnostic without pass/fail thresholds. Curvature may be legitimate printer behaviour. '
                         'This tests the final ICC, not the raw measurements or the intermediate regularization model. '
                         'The inverse blue-sky check and a printed gradient are complementary.', paths=results)
    out.mkdir(parents=True)
    (out / 'rgb-gradients.json').write_text(json.dumps(result, indent=2, allow_nan=False))
    lines = ['# RGB gradient diagnostic', '',
             '| Intent | RGB path | Max Lab second difference | Max/median colour step | Worst position (0–1) |',
             '|---|---|---:|---:|---:|']
    for r in results:
        m = r['metrics']; ratio = m['colourStepMaxOverMedian']
        ratio_text = '–' if ratio is None else f'{ratio:.3f}'
        lines.append(f"| {r['intent']} | {r['path']} | {m['labSecondDifference']['max']:.6g} | {ratio_text} | {m['worstAt']:.4f} |")
    lines += ['', result['caveat']]
    (out / 'rgb-gradients.md').write_text('\n'.join(lines) + '\n')
    return result


if __name__ == '__main__':
    p = argparse.ArgumentParser()
    p.add_argument('profile'); p.add_argument('executable'); p.add_argument('output')
    a = p.parse_args(); run(a.profile, a.executable, a.output)
