# Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
# Copyright (c) 2026 Christer Törnkvist.
# SPDX-License-Identifier: GPL-3.0-or-later
"""Photographic RGB -> printer RGB -> predicted Lab gradient diagnostics."""
import argparse
import json
from pathlib import Path
import numpy as np
from lcms_float import LittleCMS
from rgb_gradients import ramps
from sky_ramp import delta_e00, sha, stats


def metrics(rgb, lab):
    """Uniformly sampled paths. Interior mask excludes hard device clipping.
    Small positive output steps are not required to be perceptually uniform.
    """
    rgb=np.asarray(rgb);lab=np.asarray(lab);dt=1/(len(rgb)-1)
    mask=np.all((rgb>.002)&(rgb<.998),axis=1)
    triples=mask[:-2]&mask[1:-1]&mask[2:]
    pairs=mask[:-1]&mask[1:]
    curve=np.linalg.norm(np.diff(lab,n=2,axis=0),axis=1)/dt**2
    steps=delta_e00(lab[:-1],lab[1:]);active=steps[pairs]
    median=float(np.median(active)) if len(active) else 0
    changes=np.any(np.abs(np.diff(rgb,axis=0))>1e-12,axis=1)
    longest=length=1
    for changed in changes:
        length=1 if changed else length+1;longest=max(longest,length)
    return dict(interiorFraction=float(mask.mean()),interiorTriples=int(triples.sum()),
                interiorCurvatureP95=float(np.percentile(curve[triples],95)) if triples.any() else None,
                interiorCurvatureMax=float(curve[triples].max()) if triples.any() else None,
                colourStep=stats(steps),interiorStepMaxOverMedian=float(active.max()/median) if median>1e-8 else None,
                lightnessReversals=int(((np.diff(lab[:,0]) < -1e-4)&pairs).sum()),
                uniqueDeviceCodes=int(len(np.unique(rgb,axis=0))),unchangedSteps=int((~changes).sum()),longestPlateau=int(longest),
                labSpan=float(np.linalg.norm(np.ptp(lab[mask],axis=0))) if mask.any() else None)


def run(profile,out,samples=1025):
    profile,out=Path(profile),Path(out)
    if out.exists(): raise ValueError('Output directory already exists.')
    digest=sha(profile);cmm=LittleCMS();records=[]
    for space in ('sRGB','Adobe RGB (1998)'):
        for intent,label in ((1,'relative colorimetric'),(0,'perceptual')):
            for bpc in (False,True):
                for name,source in ramps(samples).items():
                    for bits in (None,16,8):
                        device=cmm.photo_transform(profile,source,space,intent,bpc,bits)
                        lab=cmm.transform(profile,device,'f')
                        records.append(dict(path=name,sourceSpace=space,intent=label,bpc=bpc,
                                            precision='float' if bits is None else str(bits)+'-bit',metrics=metrics(device,lab)))
    if sha(profile)!=digest: raise ValueError('Profile changed during check.')
    floating=[r for r in records if r['precision']=='float']
    # Matching per-path metrics support relative candidate guardrails.
    comparison=[]
    for r in floating:
        m=r['metrics']
        if m['interiorTriples']>=20:
            comparison.append(dict(key=' | '.join([r['sourceSpace'],r['intent'],str(r['bpc']),r['path']]),
                                   curvatureP95=m['interiorCurvatureP95'],curvatureMax=m['interiorCurvatureMax'],
                                   lightnessReversals=m['lightnessReversals'],interiorFraction=m['interiorFraction'],labSpan=m['labSpan']))
    result=dict(schemaVersion=1,documentType='inkprof.photo-gradient-check',profileSHA256=digest,
                samples=samples,cmm=dict(name='LittleCMS',version=cmm.version),paths=records,comparisonMetrics=comparison,
                method='Working RGB ICC -> printer ICC (intent and BPC) -> relative A2B predicted Lab. Float, 16-bit and 8-bit input/output buffers.',
                caveat='Numerical diagnostic, not physical print validation. Quantization plateaus are expected. Hard device clipping is excluded from comparison metrics, but this is not a proven physical-gamut mask. LittleCMS is not Photoshop or a printer driver.')
    out.mkdir(parents=True)
    (out/'photo-gradients.json').write_text(json.dumps(result,indent=2,allow_nan=False))
    lines=['# Photographic gradient conversion','',result['method'],'',result['caveat'],'',
           '| Source | Intent | BPC | Path | Precision | Interior curvature P95 | Reversals | Unique RGB codes | Unchanged steps |',
           '|---|---|---|---|---|---:|---:|---:|---:|']
    for r in records:
        m=r['metrics'];v=m['interiorCurvatureP95'];value='unavailable' if v is None else f'{v:.4g}'
        lines.append(f"| {r['sourceSpace']} | {r['intent']} | {r['bpc']} | {r['path']} | {r['precision']} | {value} | {m['lightnessReversals']} | {m['uniqueDeviceCodes']} | {m['unchangedSteps']} |")
    (out/'photo-gradients.md').write_text('\n'.join(lines)+'\n')
    return result

if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('profile');p.add_argument('output');a=p.parse_args();run(a.profile,a.output)
