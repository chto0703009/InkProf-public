import sys, unittest, tempfile, struct, hashlib
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'analysis'))
from rename_icc import rename, tags
from PIL import ImageCms

class RenameTests(unittest.TestCase):
    def test_unicode_name_and_preserved_tags(self):
        with tempfile.TemporaryDirectory() as root:
            root=Path(root);source=root/'source.icc';dest=root/'new.icc'
            source.write_bytes(ImageCms.ImageCmsProfile(ImageCms.createProfile('sRGB')).tobytes())
            original=source.read_bytes();name='Christers Baryta ÅÄÖ_261002'
            r=rename(source,dest,name)
            self.assertEqual(ImageCms.getProfileDescription(str(dest)).strip(),name)
            self.assertEqual(source.read_bytes(),original)
            a=tags(original);b=tags(dest.read_bytes())
            self.assertEqual({k:v for k,v in a.items() if k!=b'desc'},{k:v for k,v in b.items() if k!=b'desc'})
            data=bytearray(dest.read_bytes());pid=data[84:100];data[44:48]=bytes(4);data[64:68]=bytes(4);data[84:100]=bytes(16)
            self.assertEqual(pid,hashlib.md5(data).digest());self.assertTrue(r['colourTagPayloadsUnchanged'])
    def test_invalid_source_rejected(self):
        with tempfile.TemporaryDirectory() as root:
            p=Path(root)/'bad.icc';p.write_bytes(bytes(140))
            with self.assertRaises(ValueError):rename(p,Path(root)/'out.icc','name')
if __name__=='__main__':unittest.main()
