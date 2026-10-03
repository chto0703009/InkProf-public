"""C3: measured verification print versus desired absolute D50 Lab.

No automatic profile approval. Print-chain evidence and acceptance criteria
must be reviewed separately. Original targets and measurements are immutable.
"""
import argparse
from datetime import datetime, timezone
import json
from pathlib import Path
import subprocess

import colour
import numpy as np
from profile_fit import parse_log, sha, stats


def read(path):
    return json.loads(Path(path).read_text())


def printed_id(patch):
    """TI2 identity can differ from the reference identity after rendering."""
    return str(patch['placement'].get('sampleId', patch['id']))


def local_file(root, name):
    p = (root / name).resolve()
    if not p.is_relative_to(root.resolve()):
        raise ValueError('Target artifact must remain inside its package.')
    return p


def validate(reference, measurement):
    if reference.get('documentType') != 'inkprof.verification-target':
        raise ValueError('Select a C2 verification target JSON.')
    if not measurement.get('complete'):
        raise ValueError('Measurement is incomplete.')
    if reference['intent'] != 'absolute colorimetric' or reference['bpc']:
        raise ValueError('This C3 analysis requires absolute colorimetric without BPC.')
    patches = reference['patches']; data = measurement['data']
    ids = list(map(str, data['ids']))
    wanted = [printed_id(p) for p in patches]
    reference_ids = [str(p['id']) for p in patches]
    others=reference.get('combinedTarget',{}).get('otherPatches',[])
    other_ids=[str(p['sampleId']) for p in others]
    if len(set(other_ids))!=len(other_ids) or set(other_ids)&set(wanted):
        raise ValueError('Invalid combined-target identity mapping.')
    expected_ids=set(wanted)|set(other_ids)
    if len(set(reference_ids)) != len(reference_ids) or len(set(ids)) != len(ids) or len(set(wanted)) != len(wanted) or set(ids) != expected_ids:
        raise ValueError('Measurement patch IDs do not match the verification target uniquely.')
    rgb = np.asarray(data['rgbPercent'], dtype=float)
    if rgb.shape != (len(ids), 3) or not np.isfinite(rgb).all():
        raise ValueError('Invalid RGB measurement definition.')
    if len(data['locations']) != len(ids):
        raise ValueError('Missing measurement locations.')
    lookup = {v: k for k, v in enumerate(ids)}
    by_id = {str(p['id']): p for p in patches}
    for p in others:
        k=lookup[str(p['sampleId'])]
        if (p['role'] not in ('fit','adaptive_holdout','control') or
            str(data['locations'][k])!=p['placement']['location'] or
            not np.allclose(rgb[k],p['rgbPercent'],atol=1e-4,rtol=0)):
            raise ValueError('Combined non-verification patch role, location or RGB changed.')
    for p in patches:
        k = lookup[printed_id(p)]
        if str(data['locations'][k]) != p['placement']['location']:
            raise ValueError('Measurement location differs from the printed target.')
        if not np.allclose(rgb[k]/100, p['deviceRGB'], atol=1e-6, rtol=0):
            raise ValueError('Measurement RGB differs from the printed target.')
        lab = np.asarray(p['referenceLabD50Absolute'], dtype=float)
        if lab.shape != (3,) or not np.isfinite(lab).all():
            raise ValueError('Invalid desired Lab.')
        if p['role'] not in ('colour', 'gray', 'challenge', 'repeat', 'paperwhite'):
            raise ValueError('Unsupported target role.')
        if p['role'] == 'repeat':
            original = by_id.get(str(p['repeatOf']))
            if not original or original['role'] == 'repeat' or original['deviceRGB16'] != p['deviceRGB16'] or original['referenceLabD50Absolute'] != p['referenceLabD50Absolute']:
                raise ValueError('Invalid repeated-patch relationship.')
    spectra = np.asarray(data['spectra'], dtype=float)
    if spectra.shape != (len(ids), len(data['wavelengthNm'])) or spectra.shape[1] < 2 or not np.isfinite(spectra).all():
        raise ValueError('Complete spectral measurements are required.')
    return dict(ids=ids, locations=data['locations'], rgb=rgb.tolist())


def analyse(reference, measurement, readings):
    validate(reference, measurement)
    measured = {str(p['sampleId']): p for p in readings}
    if len(measured) != len(readings) or set(measured) != set(map(str,measurement['data']['ids'])):
        raise ValueError('Incomplete or duplicated measured Lab.')
    patches = []
    for p in reference['patches']:
        q = measured[printed_id(p)]; lab = np.asarray(q['measuredLab'])
        desired = np.asarray(p['referenceLabD50Absolute'])
        predicted = np.asarray(p['predictedLabD50Absolute'])
        patches.append(dict(sampleId=str(p['id']), measurementSampleId=printed_id(p), coordinate=p['placement']['coordinate'], page=p['placement']['page'],
                            role=p['role'], gamutAssessment=p['gamutAssessment'], repeatOf=p['repeatOf'] or None,
                            desiredLab=desired.tolist(), measuredLab=lab.tolist(), predictedLab=predicted.tolist(),
                            deltaE00=float(colour.delta_E(desired, lab, method='CIE 2000')),
                            predictedDeltaE00=float(colour.delta_E(predicted, lab, method='CIE 2000')),
                            deltaL=float(lab[0]-desired[0]), deltaA=float(lab[1]-desired[1]), deltaB=float(lab[2]-desired[2]),
                            measuredChroma=float(np.hypot(lab[1],lab[2]))))
    unique = [p for p in patches if p['role'] not in ('repeat','paperwhite')]
    groups = {name: stats([p for p in patches if p['role'] == name]) for name in ('gray','colour','challenge','repeat')}
    groups['uniqueAll'] = stats(unique)
    groups['uniqueModelReachable'] = stats([p for p in unique if p['gamutAssessment'] == 'model-reachable'])
    groups['allIncludingRepeats'] = stats([p for p in patches if p['role']!='paperwhite'])
    for name, selector in [('dark',lambda p:p['desiredLab'][0]<25),('highChroma',lambda p:np.hypot(*p['desiredLab'][1:])>=40)]:
        groups[name] = stats([p for p in unique if selector(p)])
    gray = [p for p in patches if p['role']=='gray']
    gray_balance = {k:float(np.mean([p[k] for p in gray])) if gray else None for k in ('deltaL','deltaA','deltaB','measuredChroma')}
    gray_balance['maxMeasuredChroma'] = max((p['measuredChroma'] for p in gray),default=None)
    by_id = {p['sampleId']:p for p in patches}; repeats=[]
    for p in patches:
        if p['role']=='repeat':
            original=by_id[str(p['repeatOf'])]
            repeats.append(dict(sampleId=p['sampleId'],repeatOf=str(p['repeatOf']),coordinate=p['coordinate'],originalCoordinate=original['coordinate'],
                                deltaE00=float(colour.delta_E(p['measuredLab'],original['measuredLab'],method='CIE 2000'))))
    return dict(summary=groups['uniqueAll'], groups=groups, grayBalance=gray_balance, patches=patches,
                repeatedPrintedPatches=dict(summary=stats(repeats),pairs=repeats),
                pairedSweepRepeatability=measurement.get('pairedReadings',{}).get('directionComparison',{}),
                rankedIDs=[p['sampleId'] for p in sorted(patches,key=lambda p:-p['deltaE00'])])


def run(reference_file, measurement_file, executable, output, print_settings=None):
    reference_file=Path(reference_file).resolve(); measurement_file=Path(measurement_file).resolve()
    reference=read(reference_file);measurement=read(measurement_file)
    expected=validate(reference,measurement)
    root=reference_file.parent; session=measurement_file.parent
    profile=local_file(root,reference['printerProfile']['file'])
    target_ti2=local_file(root,reference['printPackage']['ti2'])
    # Use the immutable revision copy beside the JSON, not a mutable chart-mean.ti3.
    ti3=measurement_file.with_suffix('.ti3')
    artifacts=[(profile,reference['printerProfile']['sha256']), (target_ti2,reference['printPackage']['ti2SHA256']),
               (ti3,measurement['sourceTI3SHA256']), (session/'chart.json',measurement['chartJSONSHA256']),
               (session/'source.ti2',reference['printPackage']['ti2SHA256'])]
    for path,digest in artifacts:
        if sha(path)!=digest:raise ValueError(f'Artifact hash mismatch: {path.name}')
    artifacts += [(reference_file,sha(reference_file)),(measurement_file,sha(measurement_file))]
    output=Path(output);output.mkdir(parents=True,exist_ok=False)
    args=['-v2','-k','-I','a','-i','D50','-o','1931_2']
    from fwa import arguments as fwa_arguments
    args += fwa_arguments(reference,measurement.get('measurementCondition',{}),ti3)
    version=subprocess.run([str(executable),'-?'],capture_output=True,timeout=15)
    completed=subprocess.run([str(executable),*args,str(ti3),str(profile)],stdout=subprocess.PIPE,stderr=subprocess.STDOUT,timeout=120)
    log=completed.stdout.decode(errors='replace');(output/'profcheck.log').write_text(log)
    if completed.returncode:raise ValueError('profcheck failed; inspect profcheck.log.')
    readings=parse_log(log,expected)
    result=analyse(reference,measurement,readings)
    for path,digest in artifacts:
        if sha(path)!=digest:raise ValueError('Input changed during C3 analysis.')
    result.update(schemaVersion=1,documentType='inkprof.verification-check',createdUTC=datetime.now(timezone.utc).isoformat(),
                  status='insufficient-evidence',qualityValidated=False,
                  purpose='Diagnostic independent-print comparison; no automatic profile acceptance',
                  combinedTarget=bool(reference.get('combinedTarget')), excludedNonVerificationCount=len(reference.get('combinedTarget',{}).get('otherPatches',[])),
                  decisionReasons=['Print colour-management chain has not been verified.','Acceptance criteria have not been approved.'],
                  primaryMetric='CIEDE2000 against desired absolute D50 Lab; unique patches in main summary',
                  colorimetry=dict(method='Argyll profcheck spectral integration',illuminant='D50',observer='1931_2',fwaCompensation=reference.get('fwaCompensation',False),fwaIlluminant=reference.get('fwaIlluminant'),labPrecision='six decimal places',measurementCondition=measurement.get('measurementCondition',{})),
                  reportedPrintSettings=print_settings or {},printChainVerified=False,criteria=reference.get('criteria',{}),
                  limitations=['Model-reachable is a numerical classification, not proof of physical gamut.',
                               'Targets were screened using this profile, although separate from its training patches.',
                               'If C2 measurements are used to train a later ICC, they are not independent validation data for that later profile.',
                               'Challenge patches are included in uniqueAll but reported separately.',
                               'Paired sweep differences measure repeatability, not accuracy.',
                               'Repeated printed patches combine positional print variation and measurement variation.',
                               'Any paperwhite patch is a compensation reference, excluded from independent scores.',
                               'Forward/reverse direction is operator-controlled; software does not independently verify it.'],
                  sources=[dict(path=str(p),sha256=h) for p,h in artifacts],
                  tool=dict(executable=str(executable),arguments=args,versionOutput=(version.stdout+version.stderr).decode(errors='replace'),colourVersion=colour.__version__))
    (output/'verification-check.json').write_text(json.dumps(result,indent=2,allow_nan=False))
    lines=['# C3 – verifieringsutskrift','', '**Status: otillräckligt underlag för profilgodkännande.** Utskriftens färghantering och acceptansgränser är ännu inte verifierade.','',
           'Primär jämförelse: önskat absolut D50-Lab mot spektralt uppmätt D50/2° Lab. Profilens förutsägelse används endast som separat diagnostik.', '',
           '## Resultat', '', '| Grupp | Antal | Medel ΔE00 | Median | P95 | Max |','|---|---:|---:|---:|---:|---:|']
    for name,s in result['groups'].items():
        lines.append('| '+name+' | '+str(s['count'])+' | '+' | '.join(f'{s[k]:.4f}' if s[k] is not None else '—' for k in ('mean','median','p95','max'))+' |')
    lines+=['','Grupper överlappar. Huvudresultatet uniqueAll räknar varje originalpatch en gång; challenge redovisas även separat.', '',
            '## Gråbalans', '', json.dumps(result['grayBalance'],ensure_ascii=False), '',
            'deltaL/A/B är medelvärden med tecken, uppmätt minus önskat. Chroma är uppmätt C*ab för de avsedda neutrala patcharna.', '',
            '## Upprepningar','', 'Separata upprepade tryckta patchar: '+json.dumps(result['repeatedPrintedPatches']['summary']), '',
            '## Rapporterade utskriftsinställningar (ej verifierade)','',json.dumps(result['reportedPrintSettings'],ensure_ascii=False), '',
            '## Alla patchar, störst avvikelse först','', '| Sida/koordinat | ID | Roll | Uppmätt ↔ önskat (ΔE00) | Modell ↔ mätning (ΔE00) | Önskat Lab | Uppmätt Lab |','|---|---|---|---:|---:|---|---|']
    for p in sorted(result['patches'],key=lambda p:-p['deltaE00']):
        vectors=[' / '.join(f'{x:.3f}' for x in p[k]) for k in ('desiredLab','measuredLab')]
        lines.append(f"| {p['page']}/{p['coordinate']} | {p['sampleId']} | {p['role']} | {p['deltaE00']:.4f} | {p['predictedDeltaE00']:.4f} | {vectors[0]} | {vectors[1]} |")
    lines+=['','## Spårbarhet','']+[f"- `{a['path']}` — SHA256 `{a['sha256']}`" for a in result['sources']]
    (output/'verification-check.md').write_text('\n'.join(lines)+'\n')
    from verification_feedback import run as feedback_run
    feedback_run(output/'verification-check.json', output)
    return result

if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('reference');p.add_argument('measurement');p.add_argument('executable');p.add_argument('output');p.add_argument('--print-settings')
    a=p.parse_args();run(a.reference,a.measurement,a.executable,a.output,read(a.print_settings) if a.print_settings else None)
