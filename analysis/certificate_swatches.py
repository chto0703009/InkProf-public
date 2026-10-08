# Copyright (c) 2026 Christer Törnkvist.
# SPDX-License-Identifier: GPL-3.0-or-later
# InkProf is free software under GNU GPL version 3 or later.
# Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
"""Display target, profile prediction and measurement from verified Lab evidence."""
import hashlib
import html
import json
from pathlib import Path
import numpy as np

LABELS = [('desiredHex', 'Desired'), ('predictedHex', 'Predicted'), ('hex', 'Measured')]

def lab_hex(lab):
    lab=np.asarray(lab,dtype=float)
    if lab.shape!=(3,) or not np.isfinite(lab).all():
        raise ValueError('Finite Lab triplet required')
    f=(lab[0]+16)/116
    q=np.array([f+lab[1]/500,f,f-lab[2]/200]);delta=6/29
    xyz=np.where(q>delta,q**3,3*delta**2*(q-4/29))*[.9642956764,1,.8251046025]
    b=np.array([[.8951,.2664,-.1614],[-.7502,1.7135,.0367],[.0389,-.0685,1.0296]])
    a=np.linalg.solve(b,np.diag((b@[.9504559271,1,1.0890577508])/(b@[.9642956764,1,.8251046025]))@b)
    linear=np.array([[3.2406,-1.5372,-.4986],[-.9689,1.8758,.0415],[.0557,-.2040,1.0570]])@a@xyz
    rgb=12.92*linear;high=linear>.0031308
    rgb[high]=1.055*linear[high]**(1/2.4)-.055
    return '#'+''.join(f'{int(v):02X}' for v in np.floor(np.clip(rgb,0,1)*255+.5))

def enrich(patches, report, folder):
    """Legacy certificates lack target Lab; recover only from verified C3 source."""
    if isinstance(patches,dict):patches=[patches]
    evidence=[]
    source=report.get('sources',{}).get('c3_report',{})
    if source:
        base=Path(folder).resolve();path=(base/source['file']).resolve()
        if not path.is_relative_to(base):raise ValueError('C3 source outside report folder')
        if path.exists():
            raw=path.read_bytes()
            if hashlib.sha256(raw).hexdigest()!=source['sha256']:raise ValueError('C3 source checksum mismatch')
            evidence=json.loads(raw).get('patches',[])
            if isinstance(evidence,dict):evidence=[evidence]
    result=[]
    for item in patches:
        item=dict(item)
        matches=[p for p in evidence if str(p['sampleId'])==str(item['sampleId']) and str(p['coordinate'])==str(item['coordinate']) and p.get('page')==item.get('page')]
        for key in ('desired','predicted'):
            lab=item.get(key+'Lab')
            if not lab and len(matches)==1:lab=matches[0].get(key+'Lab')
            if lab:item[key+'Hex']=lab_hex(lab)
        result.append(item)
    return result

def html_chips(patch):
    cells=[]
    for key,label in LABELS:
        color=patch.get(key)
        box=('background:'+color) if color else 'background:repeating-linear-gradient(45deg,#eee,#eee 4px,#fff 4px,#fff 8px)'
        cells.append('<div style="flex:1"><div style="height:40px;border:1px solid #777;print-color-adjust:exact;-webkit-print-color-adjust:exact;'+html.escape(box,quote=True)+'"></div>'+label+('' if color else ' (unavailable)')+'</div>')
    return '<div style="display:flex;gap:3px">'+''.join(cells)+'</div>'

def pdf_chips(patch):
    from reportlab.platypus import Table,TableStyle
    from reportlab.lib.units import mm
    from reportlab.lib import colors
    table=Table([['' if patch.get(key) else 'Saknas' for key,_ in LABELS],[label for _,label in LABELS]],colWidths=[16.3*mm]*3,rowHeights=[13*mm,5*mm])
    commands=[('FONTSIZE',(0,0),(-1,-1),6),('LEFTPADDING',(0,0),(-1,-1),1),('BOX',(0,0),(-1,0),.3,colors.grey)]
    for i,(key,_) in enumerate(LABELS):
        commands.append(('BACKGROUND',(i,0),(i,0),colors.HexColor(patch.get(key) or '#eeeeee')))
    table.setStyle(TableStyle(commands));return table
