import sys
from pathlib import Path
import tempfile
import unittest
import xml.etree.ElementTree as ET
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'exchange'))
from repair_mxf_compatibility import repair

class CompatibilityTest(unittest.TestCase):
    def test_explicit_loss_and_unchanged_spectra(self):
        ns='http://colorexchangeformat.com/CxF3-core'
        def fixture(rgb):
            a='<cc:CxF xmlns:cc="'+ns+'"><cc:Resources><cc:ObjectCollection>'
            for kind in ('M0_Measurement','Target'):
                a+='<cc:Object ObjectType="'+kind+'" Name="'+kind+'7" Id="'+kind+'">'
                if kind=='Target':a+='<cc:DeviceColorValues><cc:ColorRGB>'+''.join('<cc:'+c+'>'+v+'</cc:'+c+'>' for c,v in zip('RGB',rgb))+'</cc:ColorRGB></cc:DeviceColorValues>'
                else:a+='<cc:ColorValues><cc:ReflectanceSpectrum>'+' '.join(['0.123456789']*36)+'</cc:ReflectanceSpectrum></cc:ColorValues>'
                a+='<cc:TagCollection Name="Location">'+''.join('<cc:Tag Name="'+k+'" Value="'+v+'"/>' for k,v in [('Page','1'),('Row','0'),('Column','0')])+'</cc:TagCollection></cc:Object>'
            return a+'</cc:ObjectCollection><cc:ColorSpecificationCollection/></cc:Resources><cc:CustomResources><x:CustomAttributes xmlns:x="http://www.xrite.com/products/prism" NumberPatchRows="1" NumberPatchColumns="1" NumberPatchPages="1" numberCorePatches="1"/></cc:CustomResources></cc:CxF>'
        with tempfile.TemporaryDirectory() as d:
            d=Path(d);src=d/'s.mxf';ref=d/'r.mxf';out=d/'o.mxf'
            src.write_text(fixture(['12.49','20.6','255']));ref.write_text(fixture(['12','21','255']))
            with self.assertRaisesRegex(ValueError,'opt-in'):repair(src,ref,out)
            self.assertFalse(out.exists())
            report=repair(src,ref,out,allow_rgb8_rounding=True)
            self.assertTrue(report['spectraUnchanged']);self.assertEqual(report['mapping'][0]['exportedRGB255'],[12,21,255])
            self.assertEqual(report['mapping'][0]['sourceTargetName'],'Target7')
            with self.assertRaisesRegex(ValueError,'already exists'):repair(src,ref,out,allow_rgb8_rounding=True)
if __name__=='__main__':unittest.main()
