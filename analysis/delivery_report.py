# Copyright (c) 2026 Christer Törnkvist.
# SPDX-License-Identifier: GPL-3.0-or-later
# InkProf is free software under GNU GPL version 3 or later.
# Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
"""Identify the renamed delivery ICC separately from the checked source ICC."""
import html
import json
import sys
from pathlib import Path
from urllib.parse import quote


def details(delivery):
    return ([delivery['conversionNote']] if delivery.get('conversionNote') else []) + [f"File: {Path(delivery['file']).name}", 'Internal profile name: '+delivery['internalName'],
            'Delivery file SHA-256: '+delivery['sha256'],
            'Source ICC SHA-256 before delivery naming: '+delivery['sourceSHA256'],
            'Only profile naming information and necessary file structure/identity fields have changed. All other ICC tags, including colour computation tables, are byte-identical.']


def create(folder):
    folder = Path(folder)
    r = json.loads((folder/'final-report.json').read_text(encoding='utf-8'))
    delivery = json.loads((folder/'icc-delivery.json').read_text(encoding='utf-8'))
    if delivery['sourceSHA256'] != r['profile']['sha256']:
        conversion=json.loads((folder/'conversion-v4.json').read_text())
        if (conversion['inputSHA256']!=r['profile']['sha256'] or conversion['outputSHA256']!=delivery['sourceSHA256'] or conversion['problems']):
            raise ValueError('Delivery and report lack matching conversion evidence')
        r['deliveryConversion']=conversion
        delivery['conversionNote']='Delivered v4.4 is derived from the checked v2. Colorimetric tables are unchanged; perceptual/saturation tables are remapped. Separate application print assessment is required.'
    secondary=folder/'icc-delivery-secondary.json'
    if secondary.exists():
        second=json.loads(secondary.read_text())
        conversion=json.loads((folder/'conversion-v4.json').read_text())
        if conversion['inputSHA256']!=r['profile']['sha256'] or conversion['outputSHA256']!=second['sourceSHA256'] or conversion['problems']:
            raise ValueError('Secondary delivery lacks matching conversion evidence')
        r['secondaryDeliveryProfile']=second
        delivery['conversionNote']='Also delivered: '+Path(second['file']).name+'. The v4.4 copy preserves colorimetric tables but remaps perceptual/saturation mapping. The certificate identifies the checked v2; assess v4.4 prints in the intended application.'
    r['deliveryProfile'] = delivery
    (folder/'final-report.json').write_text(json.dumps(r,indent=2,ensure_ascii=False),encoding='utf-8')
    if r['documentType'] == 'inkprof.numerical-report':
        from numerical_report import create as render
    else:
        section = '<h2>Delivered ICC profile</h2>'+''.join('<p>'+html.escape(x)+'</p>' for x in details(delivery))
        section += "<p><a href='"+quote(delivery['file'])+"'>Download named ICC profile</a></p>"
        page = (folder/'final-report.html').read_text(encoding='utf-8')
        page = page.replace('<h2>Saved ICC profile</h2>',section+'<h2>Checked ICC candidate (project original)</h2>',1)
        (folder/'final-report.html').write_text(page,encoding='utf-8')
        text = (folder/'final-report.txt').read_text(encoding='utf-8')
        text = text.replace('SAVED ICC\n','DELIVERED ICC PROFILE\n'+'\n'.join(details(delivery))+'\n\nCHECKED ICC CANDIDATE (PROJECT ORIGINAL)\n',1)
        (folder/'final-report.txt').write_text(text,encoding='utf-8')
        from workflow_final_pdf import create as render
    render(folder)


if __name__ == '__main__':
    create(sys.argv[1])
