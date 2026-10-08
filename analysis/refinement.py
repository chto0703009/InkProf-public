# Copyright (c) 2026 Christer Törnkvist.
# SPDX-License-Identifier: GPL-3.0-or-later
# InkProf is free software under GNU GPL version 3 or later.
# Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
"""Reviewable forward-error refinement proposals; never merges measurements."""
import argparse
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import subprocess
import uuid
import numpy as np
from scipy.spatial import cKDTree
from colour.difference import delta_E_CIE2000
from profile_fit import parse_log


def sha(p):
    return hashlib.sha256(Path(p).read_bytes()).hexdigest()


def points(x):
    x = np.asarray(x, dtype=float)
    if x.ndim != 2 or x.shape[1] != 3 or not len(x) or not np.isfinite(x).all() or np.any((x < 0) | (x > 100)):
        raise ValueError('Expected finite RGB percent points in [0,100].')
    return x


def local_sensitivity(transform, rgb, step=.5):
    """Bounded central/one-sided differences; Lab per RGB percentage point."""
    rgb=points(rgb);probes=[];widths=[]
    for point in rgb:
        for axis in range(3):
            lo=point.copy();hi=point.copy()
            lo[axis]=max(0,lo[axis]-step);hi[axis]=min(100,hi[axis]+step)
            probes.extend([lo,hi]);widths.append(hi[axis]-lo[axis])
    lab=np.asarray(transform(np.array(probes)),float)
    if lab.shape!=(len(probes),3) or not np.isfinite(lab).all():
        raise ValueError('Invalid Jacobian probe results.')
    derivatives=(lab[1::2]-lab[::2])/np.array(widths)[:,None]
    matrices=derivatives.reshape(-1,3,3).transpose(0,2,1)
    result={}
    for point,j in zip(rgb,matrices):
        singular=np.linalg.svd(j,compute_uv=False)
        key=tuple(np.rint(point/100*65535).astype(int))
        result[key]=dict(jacobian=j.tolist(),singularValues=singular.tolist(),
            conditionNumber=float(singular[0]/singular[-1]) if singular[-1]>1e-10 else None,
            nearSingular=bool(singular[-1]<=1e-10),stepPercent=step,
            units='Lab units per RGB percentage point; Euclidean Lab sensitivity, not dE00')
    return result


def propose(training, patches, budget=24, threshold=2., radius=10., spacing=1., repeat_limit=1., gray_weight=1., norm_target=1., sensitivity=None):
    """Rank midpoint candidates supported by multiple distinct measured errors.

    RGB is quantized to the printable 16-bit grid before duplicate checks.
    The score is a heuristic, not a predicted reduction in dE00.
    """
    training = points(training)
    if isinstance(budget, bool) or int(budget) != budget or not 1 <= budget <= 10000:
        raise ValueError('Budget must be an integer from 1 to 10000.')
    if not all(np.isfinite(v) for v in [threshold, radius, spacing, repeat_limit, gray_weight, norm_target]) or min(radius, spacing, repeat_limit, gray_weight) <= 0 or threshold < 0 or norm_target < 0 or spacing > radius:
        raise ValueError('Invalid thresholds, radius, spacing or weight.')
    sensitivity = {} if sensitivity is None else sensitivity
    scale = float(np.median([x['singularValues'][0] for x in sensitivity.values()])) if sensitivity else 1.
    scale = max(scale, 1e-10)
    groups = {}
    for p in patches:
        rgb = points([p['rgbPercent']])[0]
        lab = np.asarray([p['measuredLab'], p['predictedLab']], dtype=float)
        if lab.shape != (2, 3) or not np.isfinite(lab).all():
            raise ValueError('Invalid Lab values.')
        key = tuple(np.rint(rgb / 100 * 65535).astype(int))
        groups.setdefault(key, []).append(p)
    if not groups:
        raise ValueError('No validation observations.')
    observations = []
    for key, group in sorted(groups.items()):
        labs = np.array([p['measuredLab'] for p in group])
        measured = labs.mean(axis=0)
        predicted = np.mean([p['predictedLab'] for p in group], axis=0)
        dispersion = max(float(delta_E_CIE2000(a, b)) for a in labs for b in labs)
        observations.append(dict(rgbPercent=(np.array(key)*100/65535).tolist(), sampleIds=[str(p['sampleId']) for p in group],
            measuredLab=measured.tolist(), predictedLab=predicted.tolist(), residualLab=(measured-predicted).tolist(),
            deltaE00=float(delta_E_CIE2000(measured, predicted)), repeatMaxDeltaE00=dispersion,
            quality='review_repeat' if dispersion > repeat_limit else 'usable'))
    for o in observations:
        key=tuple(np.rint(np.array(o['rgbPercent'])/100*65535).astype(int))
        if key in sensitivity:o['localSensitivity']=sensitivity[key]
    usable = [o for o in observations if o['quality']=='usable']
    weights = np.array([gray_weight if np.ptp(o['rgbPercent'])<=2 else 1. for o in usable])
    norm = float(np.sqrt(np.sum(weights*np.array([o['deltaE00'] for o in usable])**2)/weights.sum())) if usable else None
    norm_reached = norm is not None and norm <= norm_target
    xyz = points([p['rgbPercent'] for p in observations])
    tt = cKDTree(training)
    # Exclude every measured RGB, including repeats, from new print proposals.
    existing = np.vstack([training, xyz]); tree = cKDTree(existing)
    pool = {}; reuse = []; review = []
    for i, o in enumerate(observations):
        if o['quality'] != 'usable':
            review.append(dict(index=i, reason='Repeat disagreement exceeds limit')); continue
        if norm_reached or o['deltaE00'] <= threshold or tt.query(xyz[i])[0] < .005:
            continue
        neighbors = [j for j in range(len(xyz)) if j != i and np.linalg.norm(xyz[j]-xyz[i]) <= radius and observations[j]['quality']=='usable' and observations[j]['deltaE00'] > threshold]
        if not neighbors:
            review.append(dict(index=i, reason='Isolated error: no corroborating distinct RGB within radius')); continue
        reuse.append(i)
        support = float(tt.query(xyz[i])[0])
        destinations = [xyz[j] for j in neighbors]
        destinations += [training[j] for j in np.atleast_1d(tt.query(xyz[i], k=min(6,len(training)))[1]) if np.linalg.norm(training[j]-xyz[i]) <= 2*radius]
        for other in destinations:
            candidate = np.rint((xyz[i]+other)/2/100*65535)*100/65535
            distance = float(tree.query(candidate)[0])
            if distance < spacing: continue
            weight = gray_weight if np.ptp(xyz[i]) <= 2 else 1.
            score = (o['deltaE00']-threshold)*min(support/radius,1)*min(distance/radius,1)*weight
            factor=1.
            if 'localSensitivity' in o:
                displacement=candidate-xyz[i]
                predicted_change=float(np.linalg.norm(np.array(o['localSensitivity']['jacobian'])@displacement))
                factor=1+min(predicted_change/(radius*scale),1.)
                score *= factor
            if score <= 0: continue
            key = tuple(np.rint(candidate/100*65535).astype(int))
            if key not in pool:
                pool[key] = dict(rgbPercent=candidate.tolist(), score=score, errorObservationIndices=[i],
                    components=dict(excessDeltaE00=o['deltaE00']-threshold, trainingDistance=support, existingDistance=distance, userWeight=weight, sensitivityFactor=factor), role='fit')
            else:
                pool[key]['errorObservationIndices'].append(i)
                if score > pool[key]['score']:
                    pool[key].update(score=score, components=dict(excessDeltaE00=o['deltaE00']-threshold, trainingDistance=support, existingDistance=distance, userWeight=weight, sensitivityFactor=factor))
    selected = []
    for key, c in sorted(pool.items(), key=lambda kv: (-kv[1]['score'], kv[0])):
        if any(np.linalg.norm(np.array(c['rgbPercent'])-q['rgbPercent']) < spacing for q in selected): continue
        c['patchId'] = 'refine-' + uuid.uuid5(uuid.NAMESPACE_URL, ','.join(map(str,key))).hex
        selected.append(c)
        if len(selected) == budget: break
    return dict(observations=observations, reuseObservationIndices=reuse, review=review, candidates=selected,
        stopReason='norm target reached' if norm_reached else ('no usable observations' if norm is None else ('iteration budget' if len(selected)==budget else 'eligible candidates exhausted')),
        errorNorm=dict(type='weighted RMS dE00 over unique usable adaptive observations', value=norm, target=norm_target, count=len(usable), excludedCount=len(observations)-len(usable), reached=norm_reached),
        parameters=dict(budget=budget, threshold=threshold, radiusPercent=radius, minSpacingPercent=spacing, repeatLimit=repeat_limit, grayWeight=gray_weight, normTarget=norm_target),
        method='midpoints; score = excess dE00 * min(training distance/radius,1) * min(existing distance/radius,1) * gray weight * bounded directional sensitivity [1,2]',
        limitations=['Heuristic priority, not predicted error reduction.', 'Repeated RGB contributes once; repeat disagreement blocks proposal support.', 'No observed drift check or automatic merging.', 'Selected/steering measurements are adaptive_validation, never independent final validation.'])


def run(request_file, output):
    req=json.loads(Path(request_file).read_text())
    if req.get('measurementRole') != 'adaptive_validation':
        raise ValueError('Only explicitly designated adaptive_validation may steer refinement.')
    job=Path(req['jobFolder']); mf=Path(req['measurementFile']); ti3=mf.with_suffix('.ti3')
    status=json.loads((job/'status.json').read_text()); recipe=json.loads((job/'recipe.json').read_text())
    profile=job/'result/profile.icc'; m=json.loads(mf.read_text())
    if status['status']!='succeeded' or sha(profile)!=status['profileSHA256'] or sha(job/'engine.ti3')!=status['engineTI3SHA256'] or sha(job/'recipe.json')!=status['recipeSHA256']:
        raise ValueError('Profile job checksum/status mismatch.')
    if not m.get('complete') or sha(ti3)!=m.get('sourceTI3SHA256'):
        raise ValueError('Measurement incomplete or TI3 hash mismatch.')
    color=recipe['colorimetry']
    if color['mode']!='spectral' or color['illuminant']!='D50' or color['observer']!='1931_2':
        raise ValueError('Refinement requires spectral D50/2.')
    cond=m.get('measurementCondition',{}).get('interpreted','unknown')
    if cond=='unknown' or cond!=recipe['measurementCondition']['interpreted']:
        raise ValueError('Unknown or incompatible measurement condition.')
    if len(m['data'].get('wavelengthNm',[])) < 2:
        raise ValueError('Spectral measurements required.')
    raw_ti3=ti3;fwa_evidence=None
    from fwa import arguments as fwa_arguments, prepare as fwa_prepare
    if color.get('fwaPreparation')=='white-reference-spec2cie-v1' and color.get('fwaCompensation'):
        ti3,fwa_evidence=fwa_prepare(color,m.get('measurementCondition',{}),ti3,Path(output).parent/'fwa',Path(req['profcheck']).with_name('spec2cie'+Path(req['profcheck']).suffix))
        args=[req['profcheck'],'-v2','-k','-I','a',str(ti3),str(profile)]
    else:
        args=[req['profcheck'],'-v2','-k','-I','a','-i','D50','-o','1931_2',*fwa_arguments(color,m.get('measurementCondition',{}),ti3),str(ti3),str(profile)]
    result=subprocess.run(args,capture_output=True,text=True,timeout=120,check=True)
    if fwa_evidence and sha(ti3)!=fwa_evidence['compensatedTI3SHA256']:raise ValueError('Compensated basis changed during refinement analysis.')
    patches=parse_log(result.stdout,m['data'])
    selected=req.get('developmentSampleIds', [])
    if selected:
        selected=list(map(str,selected))
        if len(set(selected))!=len(selected) or not set(selected).issubset({p['sampleId'] for p in patches}):
            raise ValueError('Unknown or duplicate development IDs.')
        patches=[p for p in patches if p['sampleId'] in selected]
    sensitivity=None
    if req.get('useJacobian',False):
        from profile_grid import lookup
        sensitivity=local_sensitivity(lambda rgb:lookup(req['xicclu'],profile,rgb/100,intent='a'),
            [p['rgbPercent'] for p in patches])
    record=propose(req['trainingRGBPercent'],patches,sensitivity=sensitivity,**req['parameters'])
    record['jacobianUsed']=bool(sensitivity)
    record['evaluatedPatches']=patches
    record['developmentSampleIds']=selected
    record.update(schemaVersion=1,documentType='inkprof.refinement-proposal',name=req['name'],
        createdUTC=datetime.now(timezone.utc).isoformat(),status='proposal-not-profile-approved',
        iteration=req['iteration'], iterationId=str(uuid.uuid4()), parentIterationId=req.get('parentIterationId',''), measurementRole='adaptive_validation',measurementCondition=m['measurementCondition'],
        printComparability='User must review print recipe and drift before measuring or merging.',
        fwaPreparation=fwa_evidence,provenance=[dict(file=p.name,sha256=sha(p)) for p in [profile,mf,raw_ti3,job/'engine.ti3']],
        colorimetry=dict(intent='absolute',illuminant='D50',observer='1931_2',fwa=color.get('fwaCompensation',False),fwaIlluminant=color.get('fwaIlluminant'),engine='Argyll profcheck'),
        arguments=args)
    output=Path(output);output.mkdir(exist_ok=False)
    (output/'proposal.json').write_text(json.dumps(record,indent=2,allow_nan=False)+'\n')
    (output/'profcheck.log').write_text(result.stdout)
    if record['candidates']:
        rows=['CTI1','DESCRIPTOR "InkProf error-driven refinement"','ORIGINATOR "InkProf"','COLOR_REP "iRGB"','NUMBER_OF_FIELDS 4','BEGIN_DATA_FORMAT','SAMPLE_ID RGB_R RGB_G RGB_B','END_DATA_FORMAT',f"NUMBER_OF_SETS {len(record['candidates'])}",'BEGIN_DATA']
        for p in record['candidates']:rows.append('"'+p['patchId']+'" '+' '.join(format(x,'.17g') for x in p['rgbPercent']))
        rows.append('END_DATA');(output/'target.ti1').write_text('\n'.join(rows)+'\n')
    # Full input snapshots make proposals reproducible after moves or later edits.
    import shutil
    sources=output/'sources';sources.mkdir()
    for p,name in [(mf,'measurement.json'),(raw_ti3,'measurement.ti3'),(profile,'profile.icc'),(job/'engine.ti3','training.ti3'),(job/'recipe.json','recipe.json')]:shutil.copy2(p,sources/name)
    (output/'request.json').write_text(json.dumps(req,indent=2)+'\n')
    return record


if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('request');parser.add_argument('output');a=parser.parse_args();run(a.request,a.output)
