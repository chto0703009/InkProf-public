"""Numerical and data-integrity acceptance tests; no instrument required."""
import copy
import importlib.util
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

import numpy as np

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("spectral_analysis", ROOT / "analysis/spectral_analysis.py")
m = importlib.util.module_from_spec(spec)
spec.loader.exec_module(m)


def measurement():
    return {"schemaVersion": 1, "documentType": "inkprof.chart-measurement", "complete": True,
            "measurementCondition": {"reported": "M0"}, "chartIndex": [1, 2, 3],
            "data": {"ids": ["white", "grey", "black"], "locations": ["A1", "B1", "C1"],
                     "rgbPercent": [[100, 100, 100], [50, 50, 50], [0, 0, 0]],
                     "wavelengthNm": list(range(360, 781, 10)),
                     "spectra": [[100] * 43, [50] * 43, [0] * 43],
                     "scales": {"SpectralScale": None}}}


class SpectralTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="InkProf analysis ")
        self.addCleanup(self.temp.cleanup)
        self.folder = Path(self.temp.name)
        self.path = self.folder / "measurement.json"
        self.source = measurement()
        self.write()
        self.job = {"schemaVersion": 1, "measurementPath": str(self.path), "spectralScale": 100}

    def write(self):
        self.path.write_text(json.dumps(self.source))

    def test_physical_anchors_and_d50_white(self):
        r = m.analyse(self.job)
        xyz = np.array(r["data"]["xyz100"])
        np.testing.assert_allclose(xyz[0], [96.42, 100, 82.52], atol=.08)
        np.testing.assert_allclose(xyz[1], xyz[0] / 2, atol=1e-10)
        np.testing.assert_allclose(r["data"]["lab"], [[100, 0, 0], [76.069261, 0, 0], [0, 0, 0]], atol=1e-5)

    def test_scale_equivalence_and_source_immutable(self):
        before = self.path.read_bytes()
        a = m.analyse(self.job)
        self.assertEqual(self.path.read_bytes(), before)
        self.source["data"]["spectra"] = (np.array(self.source["data"]["spectra"]) / 100).tolist()
        self.write()
        b = m.analyse(dict(self.job, spectralScale=1))
        np.testing.assert_allclose(a["data"]["xyz100"], b["data"]["xyz100"])
        self.assertNotEqual(a["source"]["sha256"], b["source"]["sha256"])

    def test_sharma_published_delta_e_cases(self):
        # Sharma, Wu, Dalal (2005), supplementary CIEDE2000 test pairs 1–6.
        a = [[50, 2.6772, -79.7751], [50, 3.1571, -77.2803], [50, 2.8361, -74.0200],
             [50, -1.3802, -84.2814], [50, -1.1848, -84.8006], [50, -.9009, -85.5211]]
        b = [[50, 0, -82.7485]] * 6
        actual = m.colour.difference.delta_E_CIE2000(a, b)
        np.testing.assert_allclose(actual, [2.0425, 2.8615, 3.4412, 1, 1, 1], atol=5e-5)

    def test_shuffled_reference_uses_identity(self):
        r = m.analyse(self.job)
        ref = copy.deepcopy(r)
        for key in ("ids", "locations", "rgbPercent", "lab"):
            ref["data"][key] = ref["data"][key][::-1]
        self.assertEqual(m.compare(r, ref)["max"], 0)
        ref["data"]["rgbPercent"][0][0] = 10
        with self.assertRaisesRegex(ValueError, "RGB values differ"):
            m.compare(r, ref)

    def test_incompatible_comparisons_rejected(self):
        r = m.analyse(self.job)
        ref = copy.deepcopy(r)
        ref["calculation"]["illuminant"] = "D65"
        with self.assertRaisesRegex(ValueError, "settings"):
            m.compare(r, ref)
        ref = copy.deepcopy(r)
        ref["measurementCondition"] = {"reported": "M1"}
        with self.assertRaisesRegex(ValueError, "measurement conditions"):
            m.compare(r, ref)
        r["measurementCondition"] = {}
        with self.assertRaisesRegex(ValueError, "measurement conditions"):
            m.compare(r, r)

    def test_bad_inputs_rejected(self):
        for change in (lambda d: d["data"].update(wavelengthNm=[400]*43),
                       lambda d: d["data"]["spectra"][0].__setitem__(0, -1),
                       lambda d: d["data"]["spectra"][0].__setitem__(0, None),
                       lambda d: d["data"].update(ids=["white"]*3, locations=["A1"]*3),
                       lambda d: d["data"]["scales"].update(SpectralScale=1)):
            self.source = measurement()
            change(self.source)
            self.write()
            with self.assertRaises(ValueError):
                m.analyse(self.job)
        for scale in (None, 0, -1, float("nan"), True):
            with self.assertRaises(ValueError):
                m.analyse(dict(self.job, spectralScale=scale))

    def test_range_and_high_reflectance_preserved(self):
        self.source["data"]["wavelengthNm"] = list(range(380, 731, 10))
        self.source["data"]["spectra"] = [[110]*36, [50]*36, [0]*36]
        self.source.pop("measurementCondition")
        self.write()
        r = m.analyse(self.job)
        self.assertAlmostEqual(r["data"]["xyz100"][0][1], 110)
        self.assertTrue(any("Limited" in w for w in r["warnings"]))
        self.assertTrue(any("unknown" in w for w in r["warnings"]))

    def test_illuminants_and_observers(self):
        for light in m.ILLUMINANTS:
            for observer in m.OBSERVERS:
                r = m.analyse(dict(self.job, illuminant=light, observer=observer))
                np.testing.assert_allclose(r["data"]["lab"][0], [100, 0, 0], atol=1e-10)

    def test_matlab_single_patch_shape(self):
        for key in ("ids", "locations", "rgbPercent", "spectra"):
            self.source["data"][key] = self.source["data"][key][0]
        self.write()
        self.assertEqual(len(m.analyse(self.job)["data"]["lab"]), 1)

    def test_cli_atomic_no_overwrite(self):
        output = self.folder / "analysis.json"
        job = self.folder / "job.json"
        job.write_text(json.dumps(dict(self.job, outputPath=str(output))))
        run = subprocess.run([sys.executable, str(ROOT / "analysis/spectral_analysis.py"), str(job)], capture_output=True, text=True)
        self.assertEqual(run.returncode, 0, run.stderr)
        before = output.read_bytes()
        with self.assertRaises(FileExistsError):
            m.save_new(output, {"replacement": True})
        run = subprocess.run([sys.executable, str(ROOT / "analysis/spectral_analysis.py"), str(job)], capture_output=True, text=True)
        self.assertEqual(run.returncode, 2)
        self.assertEqual(output.read_bytes(), before)
        self.assertFalse(list(self.folder.glob(".inkprof-analysis-*")))


if __name__ == "__main__":
    unittest.main()
