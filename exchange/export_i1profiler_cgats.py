# Copyright (c) 2026 Christer Törnkvist.
# SPDX-License-Identifier: GPL-3.0-or-later
# InkProf is free software under GNU GPL version 3 or later.
# Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
"""Experimental native M0 export; recipient import must be tested separately."""
import argparse
import hashlib
import json
import math
import re
import shlex
from datetime import datetime
from pathlib import Path


def require(condition, message):
    if not condition:
        raise ValueError(message)


def export(measurement, output):
    measurement, output = Path(measurement), Path(output)
    sidecar = output.with_suffix('.json')
    require(output.suffix.lower() == '.txt', 'Use a .txt output filename.')
    require(not output.exists() and not sidecar.exists(), 'Output already exists.')
    raw = measurement.read_bytes()
    record = json.loads(raw)
    chart_path = measurement.parent / 'chart.json'
    chart_raw = chart_path.read_bytes()
    chart = json.loads(chart_raw)
    digest = lambda data: hashlib.sha256(data).hexdigest()
    require(record.get('documentType') == 'inkprof.chart-measurement' and record.get('complete'), 'Complete chart measurement required.')
    require(digest(chart_raw) == record['chartJSONSHA256'], 'Chart hash differs.')
    condition = record['measurementCondition']
    require(condition['interpreted'] == 'M0' and not condition['fwaApplied'], 'Native M0 measurement required; compensated spectra are unsupported.')
    require(['DEVCALSTD', 'XRGA'] in record['metadata'], 'XRGA calibration required.')
    data = record['data']
    require(data['wavelengthNm'] == list(range(380, 731, 10)), 'Expected 36 bands, 380–730 nm.')
    count = record['expectedSourcePatches']
    require(count > 0 and all(len(data[k]) == count for k in ('ids', 'locations', 'rgbPercent', 'spectra')) and len(record['chartIndex']) == count, 'Patch counts differ.')
    require(len(set(map(str, data['ids']))) == count, 'Duplicate patch IDs.')
    rows = []
    for i, chart_index in enumerate(record['chartIndex']):
        require(isinstance(chart_index, int) and 1 <= chart_index <= len(chart['patches']), 'Invalid chart index.')
        patch = chart['patches'][chart_index - 1]
        sid, loc = str(data['ids'][i]), data['locations'][i]
        require(re.fullmatch(r'[A-Za-z0-9_.-]+', sid) is not None and re.fullmatch(r'\d+[A-Z]+', loc) is not None, 'Unsupported patch identity/location.')
        require(not patch['isPadding'] and str(patch['sampleId']) == sid and patch['sampleLoc'] == loc, 'Patch identity/location differs.')
        rgb, spectrum = data['rgbPercent'][i], data['spectra'][i]
        require(len(rgb) == 3 and all(math.isfinite(x) and 0 <= x <= 100 for x in rgb), 'Invalid RGB.')
        require(len(patch['rgbPercent']) == 3 and all(math.isfinite(a) and abs(a-b) < 1e-8 for a,b in zip(patch['rgbPercent'], rgb)), 'Chart RGB differs.')
        require(len(spectrum) == 36 and all(math.isfinite(x) and x >= 0 for x in spectrum), 'Invalid spectrum.')
        # Preserve values above 100% reflectance, e.g. fluorescent paper.
        row, letters = re.fullmatch(r'(\d+)([A-Z]+)', loc).groups()
        rows.append([sid, letters + row] + [format(x * 255 / 100, '.17g') for x in rgb] + [format(x / 100, '.17g') for x in spectrum])
    fields = ['SAMPLE_ID', 'SAMPLE_NAME', 'RGB_R', 'RGB_G', 'RGB_B'] + ['SPECTRAL_NM' + str(w) for w in data['wavelengthNm']]
    lines = ['CGATS.17', 'ORIGINATOR "InkProf experimental CGATS export"',
             'DESCRIPTOR "Native M0 spectral measurement; i1Profiler import test"',
             'MEASUREMENT_SOURCE "MeasurementCondition=M0\tFilter=no"', 'FILTER "no"',
             'KEYWORD "DEVCALSTD"', 'DEVCALSTD "XRGA"',
             'CREATED "' + datetime.now().astimezone().isoformat(timespec='seconds') + '"',
             'NUMBER_OF_FIELDS 41', 'BEGIN_DATA_FORMAT', '\t'.join(fields), 'END_DATA_FORMAT',
             'NUMBER_OF_SETS ' + str(count), 'BEGIN_DATA']
    lines += ['\t'.join(row) for row in rows]
    lines += ['END_DATA', '']
    payload = '\n'.join(lines)
    parsed = [shlex.split(line) for line in payload.split('BEGIN_DATA\n', 1)[1].split('END_DATA')[0].splitlines()]
    require(len(parsed) == count, 'Roundtrip row count failed.')
    for i, row in enumerate(parsed):
        require(len(row) == 41 and row[:2] == rows[i][:2], 'Roundtrip identity failed.')
        require(all(abs(float(row[j+2])*100/255-x) < 1e-10 for j,x in enumerate(data['rgbPercent'][i])), 'RGB roundtrip failed.')
        require(all(abs(float(row[j+5])*100-x) < 1e-10 for j,x in enumerate(data['spectra'][i])), 'Spectral roundtrip failed.')
    report = dict(documentType='inkprof.i1profiler-cgats-test', patchCount=count,
                  measurementSHA256=digest(raw), chartJSONSHA256=digest(chart_raw),
                  outputSHA256=digest(payload.encode()), recipientImportVerified=False,
                  measurementCondition=condition, rgbScale='0–255, full precision; no integer rounding',
                  spectralScale='reflectance factor; original percent divided by 100',
                  layout='SAMPLE_NAME uses global chart row; this is data transfer, not a remeasurement layout',
                  note='No FWA compensation applied. M0 interpretation and evidence are retained above.')
    output.parent.mkdir(parents=True, exist_ok=True)
    with output.open('x') as stream:
        stream.write(payload)
    with sidecar.open('x') as stream:
        json.dump(report, stream, indent=2)
    return report


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('measurement', help='Complete InkProf measurement JSON, beside its chart.json')
    parser.add_argument('output', help='New CGATS .txt filename')
    args = parser.parse_args()
    print(json.dumps(export(args.measurement, args.output), indent=2))
