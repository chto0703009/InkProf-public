"""Conservative row-order diagnostic against approximate TI2 XYZ; never reorder."""
import argparse
import json
import re
from pathlib import Path
import numpy as np
import colour
from target_check import check_target


def compare_rows(locations, measured_lab, expected_lab):
    groups = {}
    for i, loc in enumerate(locations):
        m = re.fullmatch(r'(\d+)([A-Z]+)', loc)
        if not m:
            raise ValueError('Invalid patch location')
        column = 0
        for c in m[2]:
            column = column * 26 + ord(c) - 64
        groups.setdefault(m[1], []).append((column, i))
    rows = []
    for row, entries in groups.items():
        entries.sort()
        columns = [c for c, _ in entries]
        if len(columns) < 4 or columns != list(range(1, len(columns)+1)):
            continue
        ix = [i for _, i in entries]
        a, b = np.asarray(measured_lab)[ix], np.asarray(expected_lab)[ix]
        forward = float(np.mean(colour.difference.delta_E_CIE2000(a, b)))
        reverse = float(np.mean(colour.difference.delta_E_CIE2000(a[::-1], b)))
        # Require both substantial absolute and relative improvement. These
        # are diagnostic thresholds, not profile quality acceptance limits.
        suspect = forward > 10 and forward-reverse > 5 and reverse < .5*forward
        rows.append(dict(row=row,forwardMeanDeltaE00=forward,reverseMeanDeltaE00=reverse,suspectedReverse=suspect))
    return rows


def check(chart, measurement):
    data = measurement['data']
    if not measurement.get('complete'):
        return dict(available=False, reason='Row direction check requires a complete measurement.')
    if not data.get('xyz'):
        return dict(available=False, reason='Stored XYZ is unavailable.')
    target = check_target(chart, data, data['xyz'])
    if not target['available']:
        return dict(available=False, reason=target['reason'])
    wp = colour.CCS_ILLUMINANTS['CIE 1931 2 Degree Standard Observer']['D50']
    lab = colour.XYZ_to_Lab(np.asarray(data['xyz'])/100, wp)
    rows = compare_rows(data['locations'], lab, target['expectedLab'])
    # A source-only partial row may omit printed padding: reversing that
    # subset would not model reversal of the physical scan.
    counts = {}
    for loc in data['locations']:
        key = re.match(r'^\d+', loc).group()
        counts[key] = counts.get(key, 0) + 1
    rows = [row for row in rows if counts[row['row']] == chart['stepsInPass']]
    return dict(available=True,method='Compare original and reversed row against approximate TI2 D50 Lab; heuristic only.',automaticCorrection=False,rows=rows,flaggedRows=[r for r in rows if r['suspectedReverse']])


if __name__ == '__main__':
    p=argparse.ArgumentParser();p.add_argument('chart');p.add_argument('measurement');p.add_argument('output');a=p.parse_args()
    result=check(json.loads(Path(a.chart).read_text()),json.loads(Path(a.measurement).read_text()))
    with open(a.output,'x') as f:json.dump(result,f,indent=2,allow_nan=False)
