# Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
# Copyright (c) 2026 Christer Törnkvist.
# SPDX-License-Identifier: GPL-3.0-or-later
"""Independent page-control evidence: never insert spots into profiling arrays."""
import argparse, hashlib, json, sys
from pathlib import Path
import numpy as np
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'profiles'))
from colour_math import delta_e00, xyz_to_lab

def assess(folder,reference=None,threshold=5.0):
    folder=Path(folder);request=json.loads((folder/'request.json').read_text())
    if not np.isfinite(threshold) or threshold<=0:raise ValueError('Positive finite threshold required.')
    reference=reference or {}
    if reference:
        for label in ['R','G','B']:
            xyz=np.asarray(reference.get('xyz',{}).get(label),float)
            if xyz.shape!=(3,) or not np.isfinite(xyz).all():
                raise ValueError('Invalid approved RGB reference: each colour requires three finite XYZ values. Restore or reapprove the reference before comparing prints.')
        if reference['calibrationStandard']!=request['calibrationStandard'] or reference['context']!=request['context']:
            raise ValueError('Reference printing context or calibration standard differs.')
    readings=[];seen=set()
    for i,expected in enumerate(request['readings']):
        path=folder/f'reading-{i+1:03d}.json';r=json.loads(path.read_text())
        if r['request']!=expected:raise ValueError('Reading identity differs from plan.')
        identity=(expected['page'],expected['colour'])
        if identity in seen:raise ValueError('Duplicate page control.')
        seen.add(identity)
        xyz=np.asarray(r['xyz'],float)
        if xyz.shape!=(3,) or not np.isfinite(xyz).all():raise ValueError('Invalid XYZ.')
        if r['measurementCondition']!='M0' or r['calibrationStandard']!=request['calibrationStandard'] or (request.get('instrumentSerial') and r['instrumentSerial']!=request['instrumentSerial']):
            raise ValueError('Measurement condition or instrument changed.')
        readings.append(dict(page=expected['page'],label=expected['colour'],xyz=xyz.tolist(),lab=xyz_to_lab(xyz).tolist(),
                             readingFile=path.name,sha256=hashlib.sha256(path.read_bytes()).hexdigest()))
    labels=['R','G','B'];required={(page,label) for page in range(1,request['pageCount']+1) for label in labels}
    if seen!=required:raise ValueError('Each printed page requires exactly R, G and B.')
    first={r['label']:r for r in readings if r['page']==1}
    for r in readings:
        # First-page comparison is relative only; an approved reference is required for absolute checks.
        expected=reference['xyz'][r['label']] if reference else first[r['label']]['xyz']
        r['deltaE00']=float(delta_e00(r['lab'],xyz_to_lab(expected)))
        r['flagged']=r['deltaE00']>threshold
    return dict(schemaVersion=1,documentType='inkprof.print-control-check',complete=True,required=True,
                status='review-required' if any(r['flagged'] for r in readings) else 'passed' if reference else 'reference-needed',
                referenceAvailable=bool(reference),comparison='approved project reference' if reference else 'same print, page 1; no approved reference',
                thresholdDeltaE00=threshold,excludedFromProfiling=True,readings=readings,context=request['context'],
                calibrationStandard=request['calibrationStandard'],instrumentSerial=request.get('instrumentSerial',''),
                method='Native M0, ICC D50 XYZ100 to Lab, CIEDE2000; print sanity check, not profile accuracy')

def main():
    p=argparse.ArgumentParser();p.add_argument('folder');p.add_argument('output');p.add_argument('--reference');p.add_argument('--threshold',type=float,default=5);args=p.parse_args()
    reference=json.loads(Path(args.reference).read_text()) if args.reference else None
    result=assess(args.folder,reference,args.threshold)
    with Path(args.output).open('x') as f:json.dump(result,f,indent=2,allow_nan=False)
if __name__=='__main__':main()
