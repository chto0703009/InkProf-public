# Copyright (c) 2026 Christer Törnkvist.
# SPDX-License-Identifier: GPL-3.0-or-later
# InkProf is free software under GNU GPL version 3 or later.
# Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
"""Compare paired chartread XYZ in D50/2; report physical rows above a limit."""
import argparse,json
from pathlib import Path
import numpy as np
import colour

def compare_pairs(result,threshold=1.0):
    if not np.isfinite(threshold) or threshold<=0:raise ValueError('Threshold must be positive and finite.')
    p=result['pairedReadings'];raw=p['rawMeasurement']['data']
    pairs=np.asarray(p['pairRows'],dtype=int).reshape(-1,2)-1
    xyz=np.asarray(raw['xyz'],dtype=float).reshape(-1,3)
    if not np.isfinite(xyz).all() or np.any(pairs<0) or np.any(pairs>=len(xyz)):raise ValueError('Invalid paired readings.')
    lab=colour.XYZ_to_Lab(xyz/100,colour.CCS_ILLUMINANTS['CIE 1931 2 Degree Standard Observer']['D50'])
    de=colour.difference.delta_E_CIE2000(lab[pairs[:,0]],lab[pairs[:,1]])
    locations=result['data']['locations'];locations=[locations] if isinstance(locations,str) else locations
    if len(locations)!=len(de):raise ValueError('Pair/patch count mismatch.')
    import re
    rows={}
    for loc,value in zip(locations,de):
        row=re.match(r'^\d+',loc)
        if not row:raise ValueError('Invalid physical row coordinate.')
        key=row.group();rows[key]=max(rows.get(key,0),float(value))
    flagged=[{'row':k,'maxDeltaE00':v} for k,v in rows.items() if v>threshold]
    return {'method':'CIEDE2000; stored XYZ; D50/2','threshold':threshold,
            'purpose':'Forward/reverse repeatability, not target accuracy',
            'patchDeltaE00':de.tolist(),'maxDeltaE00':float(de.max()),'flaggedRows':flagged}

if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('input');parser.add_argument('output');parser.add_argument('--threshold',type=float,default=1)
    args=parser.parse_args();data=compare_pairs(json.loads(Path(args.input).read_text()),args.threshold)
    with open(args.output,'x') as f:json.dump(data,f,indent=2,allow_nan=False)
