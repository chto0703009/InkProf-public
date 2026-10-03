# Copyright (c) 2026 Christer Törnkvist.
# SPDX-License-Identifier: GPL-3.0-or-later
# InkProf is free software under GNU GPL version 3 or later.
# Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
"""Prism MXF compatibility export with explicit, opt-in RGB8 quantization.

The source MXF and its higher-precision JSON/TI3 remain authoritative. Reference
metadata is a recipient compatibility envelope, not measurement provenance.
"""
from pathlib import Path
import argparse
import hashlib
import json
import re
import xml.etree.ElementTree as ET
from import_mxf import N, location


def repair(source, reference, output, *, allow_rgb8_rounding=False):
    source, reference, output = map(Path, (source, reference, output))
    if output.exists() or output.with_suffix('.json').exists():
        raise ValueError('Output already exists')
    data, ref = source.read_text(), reference.read_text()
    roots = [ET.fromstring(x) for x in (data, ref)]
    # This route must never silently change spectral conditions or specifications.
    specs = [r.find('c:Resources/c:ColorSpecificationCollection', N) for r in roots]
    def signature(e):
        return (e.tag, sorted(e.attrib.items()), (e.text or '').strip(),
                tuple(signature(c) for c in e))
    if any(x is None for x in specs) or signature(specs[0]) != signature(specs[1]):
        raise ValueError('Source and reference spectral specifications differ')
    objects = roots[0].findall('c:Resources/c:ObjectCollection/c:Object', N)
    targets = [o for o in objects if o.get('ObjectType') == 'Target']
    measured = [o for o in objects if o.get('ObjectType') == 'M0_Measurement']
    if len(objects) != 2*len(targets) or len(targets) != len(measured) or not targets:
        raise ValueError('Complete M0-only RGB measurement required')
    byloc = {location(o): o for o in measured}
    if len(byloc) != len(measured) or len({location(t) for t in targets}) != len(targets) or {location(t) for t in targets} != set(byloc):
        raise ValueError('Ambiguous target/measurement locations')
    proto = {}
    for kind in ('Target', 'M0_Measurement'):
        proto[kind] = re.search(r'<cc:Object ObjectType="'+kind+r'".*?</cc:Object>', ref, re.S)[0]
    chunks, mapping = [], []
    for kind in ('M0_Measurement', 'Target'):
        for rank, target in enumerate(targets, 1):
            obj = target if kind == 'Target' else byloc[location(target)]
            text = proto[kind]
            text = re.sub(r'Name="'+kind+r'\d+"', 'Name="'+kind+str(rank)+'"', text)
            text = re.sub(r' Id="[^"]+"', ' Id="c'+str(len(chunks)+1)+'"', text, count=1)
            tags = {t.get('Name'): t.get('Value') for t in obj.findall('c:TagCollection/c:Tag', N)}
            for k in ('Page', 'Row', 'Column'):
                text = re.sub(r'(Name="'+k+r'" Value=")[^"]*', lambda m:m[1]+tags[k], text)
            if kind == 'Target':
                values = [float(obj.find('c:DeviceColorValues/c:ColorRGB/c:'+ch,N).text) for ch in 'RGB']
                if not all(0 <= v <= 255 for v in values):
                    raise ValueError('RGB outside 0..255')
                rounded = [round(v) for v in values]
                error = max(abs(a-b) for a,b in zip(values,rounded))
                if error > 1e-5 and not allow_rgb8_rounding:
                    raise ValueError('RGB8 rounding requires explicit opt-in')
                for ch, value in zip('RGB', rounded):
                    text = re.sub('<cc:'+ch+'>.*?</cc:'+ch+'>', '<cc:'+ch+'>'+str(value)+'</cc:'+ch+'>', text)
                mapping.append(dict(exportTargetName='Target'+str(rank), sourceTargetName=target.get('Name'),
                                    location=location(target), sourceRGB255=values, exportedRGB255=rounded,
                                    maximumChannelError255=error))
            else:
                spectrum = obj.find('c:ColorValues/c:ReflectanceSpectrum',N)
                if spectrum is None or len(spectrum.text.split()) != 36:
                    raise ValueError('Expected 36 spectral bands')
                text = re.sub(r'(<cc:ReflectanceSpectrum[^>]*>)[^<]*', lambda m:m[1]+spectrum.text, text)
            chunks.append(text)
    result = re.sub(r'(<cc:ObjectCollection>).*?(</cc:ObjectCollection>)',
                    lambda m:m[1]+'\n\t\t\t'+'\n\t\t\t'.join(chunks)+'\n\t\t'+m[2],ref,flags=re.S)
    attrs = roots[0].find('.//{http://www.xrite.com/products/prism}CustomAttributes').attrib
    for key in ('NumberPatchRows','NumberPatchColumns','NumberPatchPages','numberCorePatches'):
        result = re.sub(key+r'="[^"]*"',key+'="'+attrs[key]+'"',result)
    parsed = ET.fromstring(result)
    new = parsed.findall('c:Resources/c:ObjectCollection/c:Object',N)
    newmeasured = {location(o):o for o in new if o.get('ObjectType')=='M0_Measurement'}
    for key,old in byloc.items():
        assert old.find('c:ColorValues/c:ReflectanceSpectrum',N).text.split() == newmeasured[key].find('c:ColorValues/c:ReflectanceSpectrum',N).text.split()
    sha=lambda b:hashlib.sha256(b).hexdigest()
    encoded=result.encode('utf-8')
    report=dict(documentType='inkprof.mxf-rgb8-compatibility-export',createdBy='InkProf',
                source=str(source.resolve()),sourceSHA256=sha(source.read_bytes()),
                reference=str(reference.resolve()),referenceSHA256=sha(reference.read_bytes()),
                outputSHA256=sha(encoded),patchCount=len(targets),spectraUnchanged=True,
                rgbQuantization='nearest integer 0..255; maximum 0.5/255 per channel',
                maximumChannelError255=max(m['maximumChannelError255'] for m in mapping),
                recipientImportVerified=False,mapping=mapping,
                notes='Reference Creator, dates, private profile settings and paper/printer metadata retained for compatibility, not source provenance. Virtual layout is not for remeasurement. Source JSON/TI3 retains full RGB precision; this export is not an exact-RGB comparison.')
    output.parent.mkdir(parents=True,exist_ok=True)
    output.write_bytes(encoded)
    output.with_suffix('.json').write_text(json.dumps(report,indent=2)+'\n')
    return report

if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__)
    for name in ('source','reference','output'):p.add_argument(name)
    p.add_argument('--allow-rgb8-rounding',action='store_true')
    a=p.parse_args();r=repair(a.source,a.reference,a.output,allow_rgb8_rounding=a.allow_rgb8_rounding)
    print(json.dumps({k:r[k] for k in ('patchCount','spectraUnchanged','maximumChannelError255')}))
