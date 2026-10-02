"""Reproducible forward-profile fit, not independent print validation."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import subprocess
import numpy as np
import colour
from fwa import arguments as fwa_arguments

NUMBER=r'[-+]?(?:\d+(?:\.\d*)?|\.\d+)(?:[eE][-+]?\d+)?'
LINE=re.compile(r'^\[('+NUMBER+r')\]\s+(.*?)\s+@\s+(.*?):\s+(.*?)\s+->\s+(.*?)\s+should be\s+(.*?)\s*$')

def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()

def parse_log(text, expected):
    lookup={(str(i),str(l)):k for k,(i,l) in enumerate(zip(expected['ids'],expected['locations']))}
    if len(lookup)!=len(expected['ids']):raise ValueError('Ambiguous patch identity.')
    patches=[];seen=set()
    for line in text.splitlines():
        match=LINE.match(line)
        if not match:continue
        error,identity,loc,rgb,predicted,measured=match.groups();key=(identity,loc)
        if key not in lookup or key in seen:raise ValueError('Unknown or duplicated profcheck patch.')
        seen.add(key);idx=lookup[key]
        vectors=[np.array([float(x) for x in item.split()]) for item in (rgb,predicted,measured)]
        if any(x.shape!=(3,) or not np.isfinite(x).all() for x in vectors):raise ValueError('Invalid profcheck colour data.')
        rgb,lab,ref=vectors
        original=np.array(expected['rgb'][idx],dtype=float)
        if not np.allclose(rgb*100,original,atol=2e-5,rtol=0):raise ValueError('Profcheck RGB does not match source.')
        de=float(colour.difference.delta_E_CIE2000(lab,ref))
        if not np.isfinite(de) or abs(de-float(error))>2e-5:raise ValueError('Independent deltaE00 calculation disagrees with profcheck.')
        coordinate=re.sub(r'^(\d+)([A-Z]+)$',r'\2\1',loc)
        patches.append(dict(sourceIndex=idx+1,sampleId=identity,sampleLoc=loc,coordinate=coordinate,
                            rgbPercent=original.tolist(),predictedLab=lab.tolist(),measuredLab=ref.tolist(),
                            deltaE00=de,argyllDeltaE00=float(error),gray=bool(np.ptp(original)<=1e-4),
                            dark=bool(ref[0]<20),highChroma=bool(np.hypot(ref[1],ref[2])>=40),
                            rgbBoundary=bool(np.any((original<=1e-4)|(original>=100-1e-4)))))
    if len(seen)!=len(lookup):raise ValueError('Profcheck output is incomplete or its format is unsupported.')
    return sorted(patches,key=lambda p:p['sourceIndex'])

def stats(patches):
    values=np.array([p['deltaE00'] for p in patches])
    if not len(values):return dict(count=0,mean=None,median=None,p95=None,max=None,rms=None)
    return dict(count=len(values),mean=float(values.mean()),median=float(np.median(values)),p95=float(np.percentile(values,95)),max=float(values.max()),rms=float(np.sqrt(np.mean(values**2))))

def run(job, expected_file, executable, output):
    job=Path(job).resolve();output=Path(output);output.mkdir(exist_ok=False)
    status=json.loads((job/'status.json').read_text());recipe=json.loads((job/'recipe.json').read_text())
    if status['status']!='succeeded':raise ValueError('Select a successful profile job.')
    profile=job/'result/profile.icc';ti3=job/'engine.ti3'
    for p,h in [(profile,status['profileSHA256']),(ti3,status['engineTI3SHA256']),(job/'recipe.json',status['recipeSHA256'])]:
        if sha(p)!=h:raise ValueError('Profile job artifact hash mismatch.')
    expected=json.loads(Path(expected_file).read_text())
    if expected['ti3SHA256']!=sha(ti3):raise ValueError('Expected patch mapping belongs to another TI3.')
    args=['-v2','-k','-I','a']
    if recipe['colorimetry']['mode']=='spectral':args+=['-i','D50','-o','1931_2']
    elif recipe['colorimetry']['mode']!='storedXYZ':raise ValueError('Unsupported recipe data mode.')
    args += fwa_arguments(recipe['colorimetry'], recipe.get('measurementCondition', {}), ti3)
    version=subprocess.run([str(executable),'-?'],stdout=subprocess.PIPE,stderr=subprocess.STDOUT,timeout=15)
    completed=subprocess.run([str(executable),*args,str(ti3),str(profile)],stdout=subprocess.PIPE,stderr=subprocess.STDOUT,timeout=120)
    text=completed.stdout.decode(errors='replace');(output/'profcheck.log').write_text(text)
    if completed.returncode:raise ValueError(f'profcheck failed ({completed.returncode}).')
    patches=parse_log(text,expected)
    for p,h in [(profile,status['profileSHA256']),(ti3,status['engineTI3SHA256'])]:
        if sha(p)!=h:raise ValueError('Profile/input changed during analysis.')
    result=dict(schemaVersion=1,documentType='inkprof.profile-fit',purpose='Training-data fit; not independent validation or convergence proof',
                metric='CIEDE2000',intent='absolute colorimetric',colorimetry=recipe['colorimetry'],
                profileSHA256=sha(profile),sourceTI3SHA256=sha(ti3),recipeSHA256=sha(job/'recipe.json'),
                tool=dict(executable=str(executable),versionOutput=version.stdout.decode(errors='replace'),arguments=args,
                          labPrecision='6 decimal places from profcheck; deltaE00 independently recomputed with Colour',colourVersion=colour.__version__),
                summary=stats(patches),groups={k:stats([p for p in patches if p[k]]) for k in ['gray','dark','highChroma','rgbBoundary']},
                definitions=dict(gray='RGB channel range <= 0.0001 percentage points',dark='Measured L* < 20',highChroma='Measured C*ab >= 40',rgbBoundary='Any RGB channel near 0 or 100 percent; groups overlap'),
                patches=patches,rankedSourceIndices=[p['sourceIndex'] for p in sorted(patches,key=lambda p:-p['deltaE00'])])
    (output/'profile-fit.json').write_text(json.dumps(result,indent=2,allow_nan=False))
    summary=result['summary'];lines=['# ICC – anpassning till mätunderlaget','', 'Detta är träningsfel, inte oberoende utskriftsvalidering eller konvergensbevis.','',f"{summary['count']} patchar; ΔE00 medel {summary['mean']:.4f}, median {summary['median']:.4f}, p95 {summary['p95']:.4f}, max {summary['max']:.4f}.",'','## Grupper','', '| Grupp | Antal | Medel ΔE00 | Max ΔE00 |','|---|---:|---:|---:|']
    for k,s in result['groups'].items():lines.append(f"| {k} | {s['count']} | {s['mean']} | {s['max']} |")
    lines+=['','Grupperna överlappar. Gray avser lika RGB-insignal, inte garanterat neutralt utskrivet Lab.','','## Samtliga patchar, störst avvikelse först','','| Koordinat | ID | ΔE00 | Beräknat Lab | Uppmätt Lab |','|---|---|---:|---|---|']
    for p in sorted(patches,key=lambda p:-p['deltaE00']):lines.append(f"| {p['coordinate']} | {p['sampleId']} | {p['deltaE00']:.4f} | {p['predictedLab']} | {p['measuredLab']} |")
    (output/'profile-fit.md').write_text('\n'.join(lines)+'\n')
    return result

if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('job');p.add_argument('expected');p.add_argument('executable');p.add_argument('output');a=p.parse_args();run(a.job,a.expected,a.executable,a.output)
