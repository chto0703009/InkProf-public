# Copyright (c) 2026 Christer Törnkvist.
# SPDX-License-Identifier: GPL-3.0-or-later
# InkProf is free software under GNU GPL version 3 or later.
# Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
"""Optional, experimental pre-regularization of measured data with ArgyllCMS.

Pass 1 builds a model profile with ``colprof -r <avgdev>``. ``profcheck -I a``
then evaluates that model at exactly the original device RGB positions. The
model values (absolute XYZ, D50 PCS, scale 0-100) are written to a separate,
explicitly labelled build TI3 that pass 2 profiles. Raw measurements are never
changed; model values are never presented as new measurements.
"""
import math
import re

METHOD = 'argyll-colprof-a2b-resample'
METHODS = (METHOD,)
# Withdrawn InkProf grid regularization (axial/Hessian); recipes using it are rejected.
WITHDRAWN = 'inkprof-grid-regularization'
DESCRIPTION = 'InkProf pre-regularization model'
ICC_D50 = (96.42, 100.0, 82.49)  # ICC PCS illuminant, XYZ * 100
TOKEN = re.compile(r'"[^"]*"|\S+')
NUMBER = r'[-+]?(?:\d+(?:\.\d*)?|\.\d+)(?:[eE][-+]?\d+)?'
LINE = re.compile(r'^\[(' + NUMBER + r')\]\s+(.*?)\s+@\s+(.*?):\s+(.*?)\s+->\s+(.*?)\s+should be\s+(.*?)\s*$')
COLOUR_FIELDS = ('XYZ_', 'LAB_', 'SPEC_', 'SPECTRAL_')


def settings(recipe):
    """Return validated pre-regularization settings, or None when off/legacy."""
    pre = recipe['engine'].get('preRegularization')
    if pre is None:
        return None
    if isinstance(pre, dict) and pre.get('method') == WITHDRAWN:
        raise ValueError('InkProf grid regularization (axial/Hessian) has been removed. Save a new B2 recipe; existing ICC files and measurements are unchanged.')
    if not isinstance(pre, dict) or pre.get('enabled') is not True or pre.get('method') not in METHODS:
        raise ValueError('Unsupported pre-regularization settings.')
    if recipe['colorimetry'].get('fwaCompensation', False) is not False and recipe['colorimetry'].get('fwaPreparation') != 'white-reference-spec2cie-v1':
        raise ValueError('Pre-regularization cannot be combined with FWA/OBA compensation in this experimental version.')
    if not _number(pre.get('avgdev')) or not 0 < pre['avgdev'] <= 100:
        raise ValueError('Pre-regularization avgdev must be a percentage > 0 and <= 100.')
    return pre


def _number(value):
    return not isinstance(value, bool) and isinstance(value, (int, float)) and math.isfinite(value)


def pass1_arguments(quality_args, colour_args, avgdev, shadow_args):
    """colprof arguments for the model pass; B2A is irrelevant and kept low."""
    return [*quality_args, '-al', *colour_args, '-r', format(avgdev, '.17g'), *shadow_args,
            '-bl', '-nc', '-D', DESCRIPTION]


def read_ti3(text):
    """Split a single-table CTI3 file, keeping every token verbatim."""
    lines = text.splitlines()
    def index(marker):
        found = [k for k, line in enumerate(lines) if line.strip() == marker]
        if len(found) != 1:
            raise ValueError(f'Expected exactly one {marker} in the TI3.')
        return found[0]
    f0, f1, d0, d1 = (index(m) for m in ('BEGIN_DATA_FORMAT', 'END_DATA_FORMAT', 'BEGIN_DATA', 'END_DATA'))
    if not lines or lines[0].strip() != 'CTI3' or not f0 < f1 < d0 < d1:
        raise ValueError('Unsupported TI3 structure.')
    if any(line.strip() for line in lines[d1 + 1:]):
        raise ValueError('Pre-regularization supports a single TI3 table only.')
    fields = ' '.join(lines[f0 + 1:f1]).split()
    rows = [TOKEN.findall(line) for line in lines[d0 + 1:d1] if line.strip()]
    if not rows or any(len(row) != len(fields) for row in rows):
        raise ValueError('TI3 rows do not match the declared fields.')
    for name in ('SAMPLE_ID', 'SAMPLE_LOC', 'RGB_R', 'RGB_G', 'RGB_B'):
        if fields.count(name) != 1:
            raise ValueError(f'TI3 field {name} is required exactly once.')
    if any(f.startswith('CMYK_') for f in fields):
        raise ValueError('Pre-regularization supports RGB output data only.')
    ids = [row[fields.index('SAMPLE_ID')].strip('"') for row in rows]
    locs = [row[fields.index('SAMPLE_LOC')].strip('"') for row in rows]
    if len(set(zip(ids, locs))) != len(rows):
        raise ValueError('Ambiguous patch identity in TI3.')
    rgb = [[float(row[fields.index('RGB_' + c)]) for c in 'RGB'] for row in rows]
    if any(not math.isfinite(v) or not -1e-9 <= v <= 100 + 1e-9 for p in rgb for v in p):
        raise ValueError('TI3 RGB values must be finite percentages.')
    return dict(header=lines[:f0], middle=lines[f1 + 1:d0], fields=fields, rows=rows, ids=ids, locations=locs, rgb=rgb)


def parse_profcheck(text, table):
    """Model (predicted) and measured absolute Lab per patch, in TI3 order."""
    lookup = {key: k for k, key in enumerate(zip(table['ids'], table['locations']))}
    model = [None] * len(lookup); measured = [None] * len(lookup); reported = [None] * len(lookup)
    for line in text.splitlines():
        match = LINE.match(line)
        if not match:
            continue
        error, identity, loc, rgb, predicted, reference = match.groups()
        k = lookup.get((identity.strip('"'), loc.strip('"')))
        if k is None or model[k] is not None:
            raise ValueError('Unknown or duplicated profcheck patch.')
        values = [[float(x) for x in item.split()] for item in (rgb, predicted, reference)]
        if any(len(v) != 3 or not all(math.isfinite(x) for x in v) for v in values):
            raise ValueError('Invalid profcheck colour data.')
        if any(abs(a * 100 - b) > 2e-5 for a, b in zip(values[0], table['rgb'][k])):
            raise ValueError('Profcheck RGB does not match the TI3.')
        model[k], measured[k], reported[k] = values[1], values[2], float(error)
    if any(v is None for v in model):
        raise ValueError('Profcheck output is incomplete or its format is unsupported.')
    return model, measured, reported


def lab_to_xyz(lab, white=ICC_D50):
    L, a, b = lab
    eps, kappa = 216 / 24389, 24389 / 27
    fy = (L + 16) / 116; fx = fy + a / 500; fz = fy - b / 200
    def inverse(t):
        return t ** 3 if t ** 3 > eps else (116 * t - 16) / kappa
    yr = fy ** 3 if L > kappa * eps else L / kappa
    return [white[0] * inverse(fx), white[1] * yr, white[2] * inverse(fz)]


def delta_e00(lab1, lab2):
    """CIEDE2000 (kL=kC=kH=1), Sharma, Wu & Dalal (2005)."""
    L1, a1, b1 = lab1; L2, a2, b2 = lab2
    C1 = math.hypot(a1, b1); C2 = math.hypot(a2, b2); Cm = (C1 + C2) / 2
    G = 0.5 * (1 - math.sqrt(Cm ** 7 / (Cm ** 7 + 25 ** 7)))
    a1p = (1 + G) * a1; a2p = (1 + G) * a2
    C1p = math.hypot(a1p, b1); C2p = math.hypot(a2p, b2)
    h1p = math.degrees(math.atan2(b1, a1p)) % 360 if C1p else 0.0
    h2p = math.degrees(math.atan2(b2, a2p)) % 360 if C2p else 0.0
    dLp = L2 - L1; dCp = C2p - C1p
    if C1p * C2p == 0:
        dhp = 0.0
    else:
        dhp = h2p - h1p
        if dhp > 180: dhp -= 360
        elif dhp < -180: dhp += 360
    dHp = 2 * math.sqrt(C1p * C2p) * math.sin(math.radians(dhp / 2))
    Lpm = (L1 + L2) / 2; Cpm = (C1p + C2p) / 2
    if C1p * C2p == 0:
        hpm = h1p + h2p
    elif abs(h1p - h2p) <= 180:
        hpm = (h1p + h2p) / 2
    else:
        hpm = (h1p + h2p + 360) / 2 if h1p + h2p < 360 else (h1p + h2p - 360) / 2
    T = (1 - 0.17 * math.cos(math.radians(hpm - 30)) + 0.24 * math.cos(math.radians(2 * hpm))
         + 0.32 * math.cos(math.radians(3 * hpm + 6)) - 0.20 * math.cos(math.radians(4 * hpm - 63)))
    dtheta = 30 * math.exp(-((hpm - 275) / 25) ** 2)
    RC = 2 * math.sqrt(Cpm ** 7 / (Cpm ** 7 + 25 ** 7))
    SL = 1 + 0.015 * (Lpm - 50) ** 2 / math.sqrt(20 + (Lpm - 50) ** 2)
    SC = 1 + 0.045 * Cpm; SH = 1 + 0.015 * Cpm * T
    RT = -math.sin(math.radians(2 * dtheta)) * RC
    return math.sqrt((dLp / SL) ** 2 + (dCp / SC) ** 2 + (dHp / SH) ** 2 + RT * (dCp / SC) * (dHp / SH))


def derived_ti3(table, xyz, avgdev=None, keywords=None, origin='Argyll colprof model values'):
    """Build TI3 with model XYZ at the original RGB positions and identities."""
    if keywords is None:
        keywords = {'INKPROF_PREREGULARIZATION_AVGDEV': format(avgdev, '.17g')}
    if len(xyz) != len(table['rows']):
        raise ValueError('Model value count differs from TI3 patch count.')
    keep = [k for k, f in enumerate(table['fields']) if not f.startswith(COLOUR_FIELDS)]
    fields = [table['fields'][k] for k in keep] + ['XYZ_X', 'XYZ_Y', 'XYZ_Z']
    header = []
    for line in table['header']:
        tokens = line.split(None, 1)
        key = tokens[0] if tokens else ''
        if key.startswith('SPECTRAL_') or (key == 'KEYWORD' and len(tokens) > 1 and tokens[1].strip('"').startswith('SPECTRAL_')):
            continue
        if key in ('NUMBER_OF_FIELDS', 'INKPROF_DERIVED_DATA') or key in keywords or key.startswith('INKPROF_PREREGULARIZATION_'):
            continue
        if key == 'COLOR_REP':
            line = 'COLOR_REP "RGB_XYZ"'
        if key == 'ORIGINATOR':
            line = 'ORIGINATOR "InkProf pre-regularization (derived model values)"'
        header.append(line)
    header += [f'INKPROF_DERIVED_DATA "{origin} at original device RGB; not measurements"',
               *(f'{key} "{value}"' for key, value in keywords.items()),
               f'NUMBER_OF_FIELDS {len(fields)}']
    rows = [' '.join([row[k] for k in keep] + [format(v, '.17g') for v in values])
            for row, values in zip(table['rows'], xyz)]
    lines = [*header, 'BEGIN_DATA_FORMAT', ' '.join(fields), 'END_DATA_FORMAT', *table['middle'], 'BEGIN_DATA', *rows, 'END_DATA']
    return '\n'.join(lines) + '\n'


def stats(values):
    values = sorted(values)
    if not values:
        return dict(count=0, mean=None, median=None, p95=None, max=None)
    def percentile(p):
        x = (len(values) - 1) * p / 100; lo = math.floor(x); hi = min(lo + 1, len(values) - 1)
        return values[lo] + (values[hi] - values[lo]) * (x - lo)
    return dict(count=len(values), mean=sum(values) / len(values), median=percentile(50),
                p95=percentile(95), max=values[-1])


def comparison(table, model_lab, measured_lab, reported, avgdev, method=METHOD, parameters=None):
    patches = []
    for k, (model, measured) in enumerate(zip(model_lab, measured_lab)):
        de = delta_e00(model, measured)
        if reported is not None and abs(de - reported[k]) > 2e-4:
            raise ValueError('Independent deltaE00 calculation disagrees with profcheck.')
        patches.append(dict(sourceIndex=k + 1, sampleId=table['ids'][k], sampleLoc=table['locations'][k],
                            rgbPercent=table['rgb'][k], measuredLab=measured, modelLab=model,
                            modelXYZ=lab_to_xyz(model), deltaE00=de))
    return dict(schemaVersion=1, documentType='inkprof.preregularization-comparison', method=method,
                avgdev=avgdev, parameters=parameters or dict(avgdev=avgdev), intent='absolute colorimetric', metric='CIEDE2000',
                purpose='Change applied to each patch by the pre-regularization model; not validation',
                summary=stats([p['deltaE00'] for p in patches]),
                patches=patches, rankedSourceIndices=[p['sourceIndex'] for p in sorted(patches, key=lambda p: -p['deltaE00'])])


def markdown(result):
    s = result['summary']
    title = 'Förregularisering med Argyll colprof -r'
    settings = ', '.join(f'{k} {v}' for k, v in result['parameters'].items())
    lines = [f'# {title}', '',
             f"Metod: `{result['method']}` ({settings}). Modellvärden vid ursprungliga RGB-positioner; rådata är oförändrade.", '',
             'ΔE00 visar hur mycket modellen ändrar varje patch, inte profilens noggrannhet.', '',
             f"{s['count']} patchar; ΔE00 medel {s['mean']:.4f}, median {s['median']:.4f}, p95 {s['p95']:.4f}, max {s['max']:.4f}.", '',
             '## Största ändringar', '', '| Plats | ID | RGB % | ΔE00 | Uppmätt Lab | Modell-Lab |', '|---|---|---|---:|---|---|']
    for k in result['rankedSourceIndices'][:50]:
        p = result['patches'][k - 1]
        fmt = lambda v: ' '.join(f'{x:.2f}' for x in v)
        lines.append(f"| {p['sampleLoc']} | {p['sampleId']} | {fmt(p['rgbPercent'])} | {p['deltaE00']:.4f} | {fmt(p['measuredLab'])} | {fmt(p['modelLab'])} |")
    return '\n'.join(lines) + '\n'
