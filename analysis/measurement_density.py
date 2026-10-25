# Copyright (c) 2026 Christer Törnkvist.
# SPDX-License-Identifier: GPL-3.0-or-later
# Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
"""Measured Lab density review and conservative, traceable trial row selection."""
import json
import hashlib
from pathlib import Path
import numpy as np
from scipy.spatial import cKDTree


def analyse(patches, radius=1., cap=4, repeat_limit=1.):
    if not np.isfinite([radius, cap, repeat_limit]).all() or not 0 < radius <= 10 or int(cap) != cap or not 1 <= cap <= 100 or repeat_limit <= 0:
        raise ValueError('Invalid density parameters.')
    rgb=np.asarray([p['rgbPercent'] for p in patches],float)
    lab=np.asarray([p['measuredLab'] for p in patches],float)
    if len(rgb)<1 or rgb.shape!=lab.shape or rgb.shape[1]!=3 or not np.isfinite(rgb).all() or not np.isfinite(lab).all() or np.any((rgb<0)|(rgb>100)):
        raise ValueError('Finite RGB percentages and measured Lab required.')
    if [p['sourceIndex'] for p in patches] != list(range(1,len(patches)+1)):
        raise ValueError('Patch rows must be in unique source order.')
    # Exact RGB16 device codes; nearby, distinct codes are never called repeats.
    codes=np.rint(rgb/100*65535).astype(int)
    repeated={}
    for i,key in enumerate(map(tuple,codes)):
        repeated.setdefault(key,[]).append(i)
    repeats=[];protected=set(np.flatnonzero(np.ptp(rgb,axis=1)<=1e-4))
    protected.update([int(np.argmin(lab[:,0])),int(np.argmax(lab[:,0]))])
    from colour import delta_E
    for group in repeated.values():
        if len(group)<2:continue
        values=lab[group]
        maximum=float(np.max(delta_E(values[:,None,:],values[None,:,:],method='CIE 2000')))
        flagged=maximum>repeat_limit
        if flagged:protected.update(group)
        repeats.append(dict(rows=[i+1 for i in group],rgbPercent=rgb[group[0]].tolist(),maxDeltaE00=maximum,reviewRequired=flagged))
    tree=cKDTree(lab);unassigned=set(range(len(lab)));groups=[];selected=set()
    # Deterministic complete-link groups: no chaining of distant Lab endpoints.
    for anchor in range(len(lab)):
        if anchor not in unassigned:continue
        group=[]
        for i in sorted(tree.query_ball_point(lab[anchor],radius)):
            if i in unassigned and all(np.linalg.norm(lab[i]-lab[j])<=radius+1e-10 for j in group):group.append(i)
        unassigned.difference_update(group)
        keep=set(group)&protected
        # Retain each device channel's local extrema to describe saturation.
        for channel in range(3):
            keep.add(group[int(np.argmin(rgb[group,channel]))]);keep.add(group[int(np.argmax(rgb[group,channel]))])
        while len(keep)<min(int(cap),len(group)):
            candidate=max((i for i in group if i not in keep),key=lambda i:(min(np.linalg.norm(rgb[i]-rgb[j]) for j in keep),-i))
            keep.add(candidate)
        selected.update(keep)
        if len(group)>1:
            spread=max(float(np.linalg.norm(lab[a]-lab[b])) for a in group for b in group)
            groups.append(dict(rows=[i+1 for i in group],count=len(group),maxLabDistanceDeltaE76=spread,
                               rgbSpanPercent=np.ptp(rgb[group],axis=0).tolist(),retainedRows=[int(i)+1 for i in sorted(keep)],retainedCount=len(keep)))
    return dict(schemaVersion=1,documentType='inkprof.measurement-density',
                parameters=dict(labRadiusDeltaE76=radius,targetPerGroup=int(cap),repeatReviewDeltaE00=repeat_limit,provisional=True),
                originalCount=len(lab),retainedCount=len(selected),omittedCount=len(lab)-len(selected),
                selectedRows=[int(i)+1 for i in sorted(selected)],protectedRows=[int(i)+1 for i in sorted(protected)],
                groups=groups,repeats=repeats,
                caveat='Measured Lab, not ICC predictions. Experimental row selection for a separate candidate, not numeric weighting or automatic approval. Original observations retained; neutral RGB, lightness extremes, local RGB extrema and inconsistent repeats protected.')


def run(request_file, output):
    request=json.loads(Path(request_file).read_text());fit_file=Path(request['fitReport'])
    digest=hashlib.sha256(fit_file.read_bytes()).hexdigest()
    if digest!=request['fitReportSHA256']:raise ValueError('Fit report changed.')
    fit=json.loads(fit_file.read_text())
    if fit['profileSHA256']!=request['profileSHA256'] or fit['sourceTI3SHA256']!=request['sourceTI3SHA256']:raise ValueError('Fit report source mismatch.')
    result=analyse(fit['patches'],request.get('radius',1),request.get('cap',4),request.get('repeatLimit',1))
    result.update(fitReportSHA256=digest,profileSHA256=fit['profileSHA256'],sourceTI3SHA256=fit['sourceTI3SHA256'],fitReport=str(fit_file))
    Path(output).write_text(json.dumps(result,indent=2,allow_nan=False))
    return result

if __name__=='__main__':
    import sys
    run(*sys.argv[1:])
