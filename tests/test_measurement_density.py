# Copyright (c) 2026 Christer Törnkvist.
# SPDX-License-Identifier: GPL-3.0-or-later
# Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
import sys,json,tempfile,hashlib,unittest
from pathlib import Path
from unittest.mock import patch
import numpy as np
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'analysis'))
import measurement_density as d
import density_comparison as c

def patches(rgb,lab):
    return [dict(sourceIndex=i+1,sampleId=str(i+1),rgbPercent=r,measuredLab=l) for i,(r,l) in enumerate(zip(rgb,lab))]

class DensityTests(unittest.TestCase):
    def test_complete_link_no_chain_and_rgb_extremes(self):
        p=patches([[20,30,40],[30,40,50],[40,50,60]],[[50,0,0],[50,.8,0],[50,1.6,0]])
        r=d.analyse(p);self.assertEqual(r['groups'][0]['rows'],[1,2]);self.assertEqual(r['selectedRows'],[1,2,3])
        self.assertTrue(all(g['maxLabDistanceDeltaE76']<=1 for g in r['groups']))

    def test_balance_preserves_neutrals_and_rgb_extrema(self):
        rgb=[[20+i,30+i*.7,40+i*.5] for i in range(10)]+[[0,0,0],[100,100,100],[30,30,30]]
        lab=[[50,i*.01,0] for i in range(10)]+[[10,0,0],[95,0,0],[50,0,0]]
        r=d.analyse(patches(rgb,lab),cap=2)
        self.assertLess(r['retainedCount'],len(rgb));self.assertTrue(set([1,10,11,12,13])<=set(r['selectedRows']))
        self.assertEqual(r,d.analyse(patches(rgb,lab),cap=2));json.dumps(r,allow_nan=False)

    def test_inconsistent_repeats_protected_and_distinct_rgb_not_called_repeat(self):
        rgb=[[20,30,40]]*5+[[20.1,30,40],[0,0,0],[100,100,100]]
        lab=[[50,i*.15,0] for i in range(5)]+[[50,0,0],[10,0,0],[95,0,0]]
        r=d.analyse(patches(rgb,lab),radius=2,cap=1,repeat_limit=.1)
        self.assertEqual(len(r['repeats']),1);self.assertTrue(r['repeats'][0]['reviewRequired'])
        self.assertTrue(set(range(1,6))<=set(r['selectedRows']))

    def test_invalid_and_fit_hash_mismatch(self):
        p=patches([[20,30,40]],[[50,0,0]])
        for kw in [dict(radius=0),dict(cap=1.5),dict(repeat_limit=0)]:
            with self.assertRaises(ValueError):d.analyse(p,**kw)
        with tempfile.TemporaryDirectory() as tmp:
            f=Path(tmp)/'fit.json';f.write_text('{}');q=Path(tmp)/'request.json';q.write_text(json.dumps(dict(fitReport=str(f),fitReportSHA256='wrong')))
            with self.assertRaises(ValueError):d.run(q,Path(tmp)/'out.json')

    def test_comparison_uses_all_original_rows_including_omitted(self):
        with tempfile.TemporaryDirectory() as tmp:
            root=Path(tmp);fit=root/'fit.json';icc=root/'candidate.icc';icc.write_bytes(b'icc')
            p=patches([[20,30,40],[50,60,70]],[[20,30,40],[50,60,70]])
            for row in p:row['deltaE00']=0
            fit.write_text(json.dumps(dict(patches=p,profileSHA256='original')))
            request=dict(fitReport=str(fit),fitSHA256=hashlib.sha256(fit.read_bytes()).hexdigest(),candidate=str(icc),candidateSHA256=hashlib.sha256(icc.read_bytes()).hexdigest(),xicclu='fake',selectedRows=[1])
            q=root/'req.json';q.write_text(json.dumps(request));out=root/'out.json'
            with patch.object(c,'lookup',side_effect=lambda exe,p,rgb,**kw:rgb*100+1):c.run(q,out)
            r=json.loads(out.read_text());self.assertEqual(r['all']['count'],2);self.assertEqual(r['omitted']['count'],1);self.assertGreater(r['all']['worstRegression'],0)

if __name__=='__main__':unittest.main()
