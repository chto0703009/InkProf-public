import json
import sys
import tempfile
import unittest
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'analysis'))
import gamut_surface as g

class GamutTests(unittest.TestCase):
    def test_parser_and_invalid_indices(self):
        text='COLOR_REP "LAB"\nBEGIN_DATA\n0 0 0 0\n1 50 20 10\n2 100 0 0\nEND_DATA\nBEGIN_DATA\n0 1 2\nEND_DATA'
        v,t=g.parse_gam(text)
        self.assertEqual(t,[[0,1,2]])
        for bad in [text.replace('0 1 2','0 1 9'),text.replace('50 20 10','nan 20 10'),text.replace('0 1 2','0 1 1')]:
            with self.assertRaises(ValueError):g.parse_gam(bad)
    def test_identity_integrity_and_views(self):
        from reportlab.graphics import renderPDF
        with tempfile.TemporaryDirectory() as folder:
            path=Path(folder)/'gamut.json'
            data=dict(profileSHA256='current',vertices=[[0,0,0],[50,20,10],[100,0,0]],triangles=[[0,1,2]],rgb=[[0,0,0],[.5,.2,.1],[1,1,1]])
            path.write_text(json.dumps(data))
            ref=dict(status='available',file=path.name,sha256=g.digest(path),profileSHA256='current')
            report=dict(gamut=ref,profile=dict(sha256='current'))
            self.assertEqual(g.load(folder,report),data)
            self.assertIn('onpointermove',g.interactive(data))
            self.assertTrue(renderPDF.drawToString(g.pdf_drawing(data)).startswith(b'%PDF'))
            report['profile']['sha256']='other'
            with self.assertRaisesRegex(ValueError,'another ICC'):g.load(folder,report)
            path.write_text('{}')
            with self.assertRaisesRegex(ValueError,'integrity'):g.load(folder,report)
    def test_unavailable_has_no_surface(self):
        self.assertIsNone(g.load('.',dict(gamut=dict(status='unavailable'))))
        self.assertEqual(g.interactive(None),'')
if __name__=='__main__':unittest.main()
