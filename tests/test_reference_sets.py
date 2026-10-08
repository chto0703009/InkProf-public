# Copyright (c) 2026 Christer Törnkvist.
# SPDX-License-Identifier: GPL-3.0-or-later
# InkProf is free software under GNU GPL version 3 or later.
# Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
import hashlib, json, sys, tempfile, unittest
from pathlib import Path
from unittest.mock import patch
import numpy as np
sys.path.insert(0, str(Path(__file__).resolve().parents[1]/'analysis'))
import reference_sets

# Synthetic values only (no third-party reference data in the repository).
LAB_TABLE = 'Patch\tLAB_L\tLAB_A\tLAB_B\nA1\t95\t-1\t1\nA2\t7\t0\t-0.5\nB1\t50\t40\t-30\nB2\t60\t-45\t30\n\t\t\t\nNotes about the data source.\n'
CIE = 'IT8.7/2\nORIGINATOR "test"\nNUMBER_OF_FIELDS 4\nBEGIN_DATA_FORMAT\nSAMPLE_ID LAB_L LAB_A LAB_B\nEND_DATA_FORMAT\nNUMBER_OF_SETS 2\nBEGIN_DATA\nA01 37.99 13.56 14.06\nA02 65.71 18.13 17.81\nEND_DATA\n'
XYZ = 'CGATS.17\nBEGIN_DATA_FORMAT\nSAMPLE_ID XYZ_X XYZ_Y XYZ_Z\nEND_DATA_FORMAT\nBEGIN_DATA\nw 96.42 100 82.49\nEND_DATA\n'
TI1 = 'CTI1\nBEGIN_DATA_FORMAT\nSAMPLE_ID RGB_R RGB_G RGB_B\nEND_DATA_FORMAT\nBEGIN_DATA\n1 100 100 100\n2 0 0 0\n3 50 20 80\nEND_DATA\n'


def write(directory, name, text):
    p = Path(directory)/name; p.write_text(text); return p


class ReferenceSetTests(unittest.TestCase):
    def test_formats(self):
        with tempfile.TemporaryDirectory() as d:
            r = reference_sets.load(write(d, 'sg.txt', LAB_TABLE))
            self.assertEqual((r['kind'], r['names'], r['values'][2]), ('lab', ['A1', 'A2', 'B1', 'B2'], [50, 40, -30]))
            self.assertIn('Notes about the data source.', r['notes'])
            self.assertEqual(r['sha256'], hashlib.sha256((Path(d)/'sg.txt').read_bytes()).hexdigest())
            r = reference_sets.load(write(d, 'cc.cie', CIE)); self.assertEqual((r['kind'], r['count'], r['names'][1]), ('lab', 2, 'A02'))
            r = reference_sets.load(write(d, 'w.txt', XYZ)); self.assertTrue(np.allclose(r['values'][0], [100, 0, 0], atol=1e-9))
            r = reference_sets.load(write(d, 'rgb.ti1', TI1)); self.assertEqual((r['kind'], r['values'][2]), ('rgb', [50, 20, 80]))

    def test_rejections(self):
        bad = [LAB_TABLE.replace('B2\t60', 'B1\t60'), LAB_TABLE.replace('\t-45', '\tx'), LAB_TABLE.replace('95', '120'),
               TI1.replace('50 20 80', '50 20 180'), TI1.replace('RGB_R RGB_G RGB_B', 'CMYK_C CMYK_M CMYK_Y'), 'Patch\tfoo\nA1\t1\n']
        with tempfile.TemporaryDirectory() as d:
            for k, text in enumerate(bad):
                with self.subTest(k=k), self.assertRaises(ValueError):
                    reference_sets.load(write(d, f'b{k}.txt', text))


def fake_lookup(exe, profile, values, direction='f', intent='a'):
    values = np.asarray(values, float)
    if direction in ('b', 'if'):
        rgb = np.clip((values + [0, 100, 100]) / [100, 200, 200], 0, 1)
        if direction == 'if': rgb[values[:, 1] > 35, 0] = 0  # make strong +a* "unreachable"
        return rgb
    return values * [100, 200, 200] - [0, 100, 100]


class ReferenceTargetTests(unittest.TestCase):
    def generate(self, text, name, repeats=1):
        from verification_target import generate
        class CMM:
            def save_lab_profile(self, path): Path(path).write_bytes(b'synthetic Lab')
        d = tempfile.mkdtemp()
        job = Path(d)/'imported'; job.mkdir(); profile = job/'profile.icc'; profile.write_bytes(b'synthetic test only')
        (job/'source.json').write_text(json.dumps({'profileSHA256': hashlib.sha256(profile.read_bytes()).hexdigest()}))
        ref = write(d, name, text)
        request = dict(externalProfile=True, name='Reference test', printing={'printer': 'fixture'}, trainingRGB=[], minTrainingRGBDistance=1/255,
                       seed=7, repeats=repeats, referenceSet=dict(file=str(ref), name='Synthetic SG'))
        with patch('verification_target.require_profile'), patch('verification_target.lookup', fake_lookup), patch('verification_target.LittleCMS', CMM):
            return generate(job, 'unused', request, Path(d)/'target'), Path(d)/'target'

    def test_lab_reference_set(self):
        r, out = self.generate(LAB_TABLE, 'sg.txt')
        unique = [p for p in r['patches'] if p['role'] != 'repeat']
        self.assertEqual([p['referenceName'] for p in unique], ['A1', 'A2', 'B1', 'B2'])
        self.assertEqual([p['role'] for p in unique], ['gray', 'gray', 'challenge', 'colour'])
        self.assertEqual(sum(p['role'] == 'repeat' for p in r['patches']), 1)
        self.assertEqual(unique[2]['referenceLabD50Absolute'], [50, 40, -30])
        self.assertEqual(r['referenceSet']['kind'], 'lab'); self.assertEqual(r['profileApplications'], 1)
        self.assertEqual((out/r['referenceSet']['file']).read_text(), LAB_TABLE)
        self.assertIn('gray', r['selection']['roles'])

    def test_rgb_reference_set(self):
        r, _ = self.generate(TI1, 'rgb.ti1', repeats=0)
        self.assertEqual(r['referenceSet']['kind'], 'rgb'); self.assertEqual(r['profileApplications'], 0)
        p = r['patches'][2]
        self.assertEqual(p['deviceRGB16'], [32768, 13107, 52428])
        self.assertTrue(np.allclose(p['referenceLabD50Absolute'], p['predictedLabD50Absolute']))

    def test_repeat_limit(self):
        with self.assertRaises(ValueError): self.generate(LAB_TABLE, 'sg.txt', repeats=5)


if __name__ == '__main__':
    unittest.main()
