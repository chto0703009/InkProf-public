# Copyright (c) 2026 Christer Törnkvist.
# SPDX-License-Identifier: GPL-3.0-or-later
# InkProf is free software under GNU GPL version 3 or later.
# Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
import sys, unittest
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'profiles'))
import preregularize as p
from test_profile_job import PRE_TI3

# Sharma, Wu & Dalal (2005) CIEDE2000 test data (selected pairs).
SHARMA=[((50,2.6772,-79.7751),(50,0,-82.7485),2.0425),((50,3.1571,-77.2803),(50,0,-82.7485),2.8615),
 ((50,0,0),(50,-1,2),2.3669),((50,2.5,0),(73,25,-18),27.1492),((50,2.5,0),(61,-5,29),22.8977),
 ((60.2574,-34.0099,36.2677),(60.4626,-34.1751,39.4387),1.2644),((63.0109,-31.0961,-5.8663),(62.8187,-29.7946,-4.0864),1.2630),
 ((90.8027,-2.0831,1.4410),(91.1528,-1.6435,0.0447),1.4441)]

class PreRegularizationTests(unittest.TestCase):
    def test_ciede2000_reference_pairs(self):
        for a,b,expected in SHARMA:
            self.assertAlmostEqual(p.delta_e00(a,b),expected,places=4)
            self.assertAlmostEqual(p.delta_e00(b,a),expected,places=4)
    def test_lab_to_xyz(self):
        self.assertEqual([round(v,10) for v in p.lab_to_xyz((100,0,0))],[96.42,100.0,82.49])
        self.assertEqual(p.lab_to_xyz((0,0,0)),[0.0,0.0,0.0])
        x=p.lab_to_xyz((3.5,0.2,-0.4));self.assertTrue(all(v>0 for v in x))
    def test_settings_and_arguments(self):
        base=dict(engine={},colorimetry=dict(mode='spectral'))
        self.assertIsNone(p.settings(base))
        good=dict(enabled=True,method=p.METHOD,avgdev=1.5)
        self.assertEqual(p.settings(dict(base,engine=dict(preRegularization=good))),good)
        for bad in (dict(good,enabled=False),dict(good,method='own-hessian'),dict(good,avgdev=0),dict(good,avgdev=True),dict(good,avgdev=float('nan'))):
            with self.assertRaises(ValueError):p.settings(dict(base,engine=dict(preRegularization=bad)))
        with self.assertRaises(ValueError):
            p.settings(dict(engine=dict(preRegularization=good),colorimetry=dict(mode='spectral',fwaCompensation=True)))
        self.assertEqual(p.pass1_arguments(['-qh'],[],2,['-V','1.5']),['-qh','-al','-r','2','-V','1.5','-bl','-nc','-D',p.DESCRIPTION])
    def test_derived_ti3_preserves_identity_and_drops_measurement_colour(self):
        t=p.read_ti3(PRE_TI3);xyz=[[1,2,3],[90,92,77],[10,9,30],[0.7,0.6,0.4]]
        text=p.derived_ti3(t,xyz,1.0);d=p.read_ti3(text)
        self.assertEqual(d['fields'],['SAMPLE_ID','SAMPLE_LOC','RGB_R','RGB_G','RGB_B','XYZ_X','XYZ_Y','XYZ_Z'])
        self.assertEqual((d['ids'],d['locations'],d['rgb']),(t['ids'],t['locations'],t['rgb']))
        self.assertEqual(d['rows'][3][2],'14.117647058823529')
        self.assertIn('NUMBER_OF_FIELDS 8',text);self.assertIn('NUMBER_OF_SETS 4',text);self.assertNotIn('SPECTRAL_',text)
        self.assertIn('INKPROF_MEASUREMENT_CONDITION "M0"',text)
        with self.assertRaises(ValueError):p.derived_ti3(t,xyz[:3],1.0)
    def test_rejects_unsupported_ti3(self):
        for text in (PRE_TI3.replace('SAMPLE_LOC ',''),PRE_TI3+'CTI3\n',PRE_TI3.replace('"4" "4A"','"3" "3A"'),PRE_TI3.replace(' 50 20 80',' 50 20 180')):
            with self.assertRaises(ValueError):p.read_ti3(text)
    def test_profcheck_parsing(self):
        t=p.read_ti3(PRE_TI3);line='[{e:f}] {i} @ {l}: {r} -> 50.000000 1.000000 2.000000 should be 50.000000 1.000000 2.000000'
        rows=[line.format(e=0,i=i,l=l,r=' '.join('%.8f'%(v/100) for v in rgb)) for i,l,rgb in zip(t['ids'],t['locations'],t['rgb'])]
        model,measured,reported=p.parse_profcheck('\n'.join(rows),t);self.assertEqual(len(model),4)
        for broken in (rows[:3],rows+rows[:1],[rows[0].replace('0.00000000','0.01000000',1)]+rows[1:]):
            with self.assertRaises(ValueError):p.parse_profcheck('\n'.join(broken),t)

if __name__=='__main__':unittest.main()
