# Copyright (c) 2026 Christer Törnkvist.
# SPDX-License-Identifier: GPL-3.0-or-later
# InkProf is free software under GNU GPL version 3 or later.
# Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
"""Turn a C3 report into reproducible diagnostic iteration priorities, not approval."""
import argparse
import hashlib
import json
from pathlib import Path
from datetime import datetime, timezone
import numpy as np
import colour

DEFAULTS = dict(MeanLimit=2.5, PatchLimit=5.0, GrayLimit=2.0,
                ModelTolerance=1.0, RepeatLimit=1.0, GrayWeight=2.0,
                MaxPriorityPatches=20)


def analyse(report, parameters=None):
    cfg = DEFAULTS | (parameters or {})
    if set(cfg) != set(DEFAULTS):
        raise ValueError('Unknown feedback parameter')
    for key, value in cfg.items():
        if isinstance(value, bool) or not np.isfinite(value) or value <= 0:
            raise ValueError(f'Invalid positive parameter: {key}')
    if int(cfg['MaxPriorityPatches']) != cfg['MaxPriorityPatches']:
        raise ValueError('MaxPriorityPatches must be an integer')
    if report.get('documentType') != 'inkprof.verification-check':
        raise ValueError('Expected a C3 verification-check report')
    patches = report['patches']
    ids = [str(p['sampleId']) for p in patches]
    if not patches or len(set(ids)) != len(ids):
        raise ValueError('Missing or duplicate patch identities')
    rows = []
    for p in patches:
        v = np.asarray([p[k] for k in ('desiredLab', 'predictedLab', 'measuredLab')], dtype=float)
        if v.shape != (3, 3) or not np.isfinite(v).all():
            raise ValueError('Invalid Lab triplet')
        expected = float(colour.delta_E(v[0], v[1], method='CIE 2000'))
        actual = float(colour.delta_E(v[0], v[2], method='CIE 2000'))
        mismatch = float(colour.delta_E(v[1], v[2], method='CIE 2000'))
        if not np.isclose(actual, p['deltaE00'], atol=1e-5) or not np.isclose(mismatch, p['predictedDeltaE00'], atol=1e-5):
            raise ValueError('Stored errors disagree with Lab values')
        if p['role'] not in ('gray','colour','challenge','repeat','paperwhite'):
            raise ValueError('Unknown patch role')
        limit = cfg['GrayLimit'] if p['role'] == 'gray' else cfg['PatchLimit']
        classification = ('model-or-print-chain-mismatch' if mismatch > cfg['ModelTolerance'] else
                          'predicted-limitation' if actual > limit else 'within-diagnostic-limits')
        # Direct model residual, never subtraction of two Delta E distances.
        priority = max(0, mismatch-cfg['ModelTolerance'])
        priority *= cfg['GrayWeight'] if p['role'] == 'gray' else 1
        priority *= 2 if actual > limit else 1
        rows.append(dict(sampleId=str(p['sampleId']), coordinate=p['coordinate'], page=p['page'],
                         role=p['role'], predictedError=expected, measuredError=actual,
                         modelMismatch=mismatch, classification=classification,
                         exceedsPatchLimit=actual > limit, priority=priority,
                         desiredLab=v[0].tolist(), predictedLab=v[1].tolist(), measuredLab=v[2].tolist()))
    unique = [p for p in rows if p['role'] not in ('repeat','paperwhite')]
    if not unique:
        raise ValueError('No unique patches')
    groups = {}
    for name, group in [('allUnique',unique),('ordinary',[p for p in unique if p['role'] in ('gray','colour')]),
                        ('gray',[p for p in unique if p['role']=='gray']),('challenge',[p for p in unique if p['role']=='challenge'])]:
        if not group: continue
        values = [p['measuredError'] for p in group]
        limit = cfg['GrayLimit'] if name=='gray' else cfg['PatchLimit']
        groups[name] = dict(count=len(group), mean=float(np.mean(values)), max=max(values),
                            meanWithinReference=float(np.mean(values))<=cfg['MeanLimit'],
                            maxWithinReference=max(values)<=limit)
    pairs = report.get('repeatedPrintedPatches',{}).get('pairs',[])
    for p in pairs:
        if not np.isfinite(p['deltaE00']) or p['deltaE00'] < 0:
            raise ValueError('Invalid repeat difference')
    repeat_status = 'unavailable' if not pairs else ('review' if max(p['deltaE00'] for p in pairs)>cfg['RepeatLimit'] else 'within-reference')
    ranked = sorted([p for p in unique if p['priority']>0],key=lambda p:(-p['priority'],p['sampleId']))
    return dict(schemaVersion=1, documentType='inkprof.verification-feedback', parameters=cfg,
                isoConformity='not-assessed', qualityApproved=False, groups=groups, patches=rows,
                repeatability=dict(status=repeat_status,pairs=pairs,
                    interpretation='Printed repeats combine measurement and positional print variation; not a confidence interval.'),
                priorities=ranked[:int(cfg['MaxPriorityPatches'])], eligibleCount=len(ranked),
                samplingAuthorization='review-required',
                recommendation='Review repeatability first' if repeat_status=='review' else 'Compare forward models at printed RGB and verify print conditions before adding patches',
                validationPolicy='If used for fitting or selection, this verification becomes development data; use fresh independent validation.',
                referencePolicy='2.5 mean / 5 max are comparison references inspired by proof control-wedge tolerances, not ISO acceptance of this target. Gray and model limits are InkProf diagnostics.')


def run(source, output, parameters=None):
    source=Path(source).resolve(); raw=source.read_bytes()
    result=analyse(json.loads(raw),parameters)
    result.update(createdUTC=datetime.now(timezone.utc).isoformat(),sourceReport=dict(
        path=source.name if Path(output).resolve()==source.parent else str(source),
        pathBase='feedback-folder' if Path(output).resolve()==source.parent else 'absolute',
        sha256=hashlib.sha256(raw).hexdigest()))
    output=Path(output); output.mkdir(parents=True,exist_ok=True)
    (output/'iteration-feedback.json').write_text(json.dumps(result,indent=2,allow_nan=False)+'\n')
    lines=['# Iteration feedback','',result['recommendation'],'',result['referencePolicy'],'',result['validationPolicy'],'',
           '| Patch | Role | Predicted error | Measured error | Model mismatch | Priority |','|---|---|---:|---:|---:|---:|']
    for p in result['priorities']:
        lines.append(f"| {p['coordinate']} | {p['role']} | {p['predictedError']:.3f} | {p['measuredError']:.3f} | {p['modelMismatch']:.3f} | {p['priority']:.3f} |")
    (output/'iteration-feedback.md').write_text('\n'.join(lines)+'\n')
    (output/'feedback.log').write_text(f"{result['createdUTC']} | C3 report verified | {len(result['patches'])} patches | {len(result['priorities'])} priorities | repeats {result['repeatability']['status']} | no ISO or profile approval\n")
    return result

if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('source');p.add_argument('output');p.add_argument('--parameters')
    a=p.parse_args();run(a.source,a.output,json.loads(Path(a.parameters).read_text()) if a.parameters else None)
