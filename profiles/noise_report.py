# Copyright (c) 2026 Christer Törnkvist.
# SPDX-License-Identifier: GPL-3.0-or-later
# InkProf is free software under GNU GPL version 3 or later.
# Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
"""Measurement noise of a locked B1 input and an approximate colprof -r.

Two noise levels are reported separately:
  * print/position noise: patches with identical RGB at different chart positions
    (what a profile should not follow); used for the colprof -r hint;
  * instrument repeatability: forward/reverse scans of the same patch, when the
    measurement has paired readings (a lower bound, not used for smoothing).
Lab uses the stored XYZ (ICC D50 PCS); spectral re-integration is done in the
profile job, so numbers here can differ slightly from a spectral build.
"""
import argparse, json, sys
from pathlib import Path
import numpy as np
sys.path.insert(0, str(Path(__file__).resolve().parent))
import colour_math as c
import preregularize as p


def run(input_folder, output):
    folder = Path(input_folder)
    table = p.read_ti3((folder / 'profiling.ti3').read_text())
    if table['fields'].count('XYZ_X') != 1:
        raise ValueError('profiling.ti3 has no XYZ values; noise needs colorimetric data.')
    k = table['fields'].index('XYZ_X')
    xyz = np.array([[float(v) for v in row[k:k + 3]] for row in table['rows']])
    rgb = np.array(table['rgb']); lab = c.xyz_to_lab(xyz)
    noise = c.estimate_noise(rgb / 100, lab)
    result = dict(schemaVersion=1, documentType='inkprof.measurement-noise', patchCount=len(rgb), printNoise=noise,
                  instrumentRepeatability=None, argyllAvgdevSuggestion=c.argyll_avgdev_suggestion(noise))
    measurement = folder / 'measurement.json'
    if measurement.is_file():
        m = json.loads(measurement.read_text())
        dc = m.get('pairedReadings', {}).get('directionComparison', {})
        if dc.get('patchDeltaE00'):
            result['instrumentRepeatability'] = dict(basis=dc.get('purpose', 'paired scans'), pairDeltaE00=c.summary(dc['patchDeltaE00']))
    Path(output).write_text(json.dumps(result, indent=2, allow_nan=False))
    return result


if __name__ == '__main__':
    a = argparse.ArgumentParser(); a.add_argument('input'); a.add_argument('output')
    v = a.parse_args(); run(v.input, v.output)
