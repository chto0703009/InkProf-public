# Copyright (c) 2026 Christer Törnkvist.
# SPDX-License-Identifier: GPL-3.0-or-later
# InkProf is free software under GNU GPL version 3 or later.
# Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
import json, sys, tempfile, unittest
from pathlib import Path
import numpy as np
sys.path.insert(0, str(Path(__file__).resolve().parents[1]/'analysis'))
import sky_ramp

# Fake xicclu: smooth Lab <-> RGB map; KINK adds a local bump in B2A near L* 47.
FAKE = """#!{python}
import sys, math
kink = {kink}
back = '-fb' in sys.argv
for line in sys.stdin:
    v = [float(x) for x in line.split()]
    if back:
        L, a, b = v
        bump = 0.01 * math.exp(-((L - 47) / 0.4) ** 2) if kink else 0.0
        out = [L / 100 + bump, (L / 100) ** 1.2, 0.5 + b / 200]
    else:
        r, g, bb = v
        out = [r * 100, -2.9, (bb - 0.5) * 200]
    print(' '.join('%.6f' % x for x in out))
"""


class SkyRampTests(unittest.TestCase):
    def check(self, kink):
        with tempfile.TemporaryDirectory() as d:
            d = Path(d); exe = d / 'xicclu'
            exe.write_text(FAKE.format(python=sys.executable, kink=kink)); exe.chmod(0o755)
            icc = d / 'p.icc'; icc.write_bytes(b'not parsed here')
            result = sky_ramp.run(icc, exe, d / 'out')
            self.assertTrue((d / 'out/sky-ramp.md').exists())
            self.assertEqual(json.loads((d / 'out/sky-ramp.json').read_text())['profileSHA256'], result['profileSHA256'])
            return result

    def test_reference_path_matches_image_sky(self):
        path = sky_ramp.sky_paths()['sky']
        self.assertEqual(path.shape, (sky_ramp.SAMPLES, 3))
        at = lambda L: path[np.argmin(abs(path[:, 0] - L))]
        self.assertAlmostEqual(at(45)[2], -40.7, delta=0.3); self.assertAlmostEqual(at(70)[2], -23.3, delta=0.3)

    def test_kink_is_detected_in_band_window(self):
        smooth = self.check(False); kinked = self.check(True)
        s = smooth['summary']['relative colorimetric']; k = kinked['summary']['relative colorimetric']
        self.assertGreater(k['secondDiffBandMax'], 20 * s['secondDiffBandMax'])
        worst = [p for p in kinked['paths'] if p['path'] == 'sky'][0]['worstSecondDifference']['L']
        self.assertAlmostEqual(worst, 47, delta=1)
        self.assertGreater(k['reversalsBand'], 0); self.assertEqual(s['reversalsBand'], 0)


if __name__ == '__main__':
    unittest.main()
