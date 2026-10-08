# Copyright (c) 2026 Christer Törnkvist.
# SPDX-License-Identifier: GPL-3.0-or-later
# Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
"""Shared Lab views: actual measurements remain separate from ICC predictions."""
import json
import math
from pathlib import Path


def plane(extent=120, title='L* = 50'):
    from reportlab.graphics.shapes import Drawing, Line, String
    from reportlab.lib.colors import HexColor
    limit=max(20,math.ceil(extent/20)*20)
    d=Drawing(480,360); scale=140/limit
    def project(a,b):return 240+a*scale,180+b*scale
    for value in range(-limit,limit+1,max(20,limit//4//20*20)):
        x,y=project(value,value)
        colour=HexColor('#627785' if value==0 else '#dce3e8')
        d.add(Line(x,40,x,320,strokeColor=colour,strokeWidth=.6))
        d.add(Line(100,y,380,y,strokeColor=colour,strokeWidth=.6))
        d.add(String(x-8,25,str(value),fontSize=8))
        d.add(String(73,y-3,str(value),fontSize=8))
    d.add(String(395,177,'a*',fontSize=11));d.add(String(234,332,'b*',fontSize=11))
    d.add(String(12,347,title,fontSize=11))
    return d,project


def point_drawing(lab,rgb=None,title='Measured colours',level=50,half=5):
    from reportlab.graphics.shapes import Circle,String
    from reportlab.lib.colors import Color
    extent=max([20]+[abs(v) for p in lab for v in p[1:]])
    d,project=plane(extent,f'{title} | L* = {level:g} +/- {half:g}')
    shown=0
    for i,p in enumerate(lab):
        if abs(p[0]-level)>half:continue
        x,y=project(p[1],p[2]);c=rgb[i] if rgb else [.13,.42,.69]
        d.add(Circle(x,y,2.5,fillColor=Color(*c),strokeColor=Color(.2,.25,.3),strokeWidth=.3));shown+=1
    d.add(String(12,6,f'{shown} of {len(lab)} points in the L* band; not a gamut boundary.',fontSize=9))
    return d


def interactive(data):
    payload=json.dumps(data,separators=(',',':'),allow_nan=False).replace('<','\\u003c')
    controls='''<div class="gamut-view"><p><label>View: <select class="lab-mode"><option value="2d">2D a*/b*</option><option value="3d">3D L*/a*/b*</option></select></label>
<label>L*: <input class="lab-level" type="range" min="0" max="100" value="50"><output>50</output></label>
<label class="lab-band-label">L* half-width: <input class="lab-band" type="number" min="0" max="50" value="5"></label>
<label><input class="lab-auto" type="checkbox"> Rotate automatically</label></p><p class="lab-status"></p>
<canvas width="850" height="520" style="width:100%;max-width:850px;height:auto;touch-action:none" aria-label="CIELAB L* a* b* view"></canvas><script type="application/json">'''
    return controls+payload+'</script></div><script>'+Path(__file__).with_name('gamut_view.js').read_text()+'</script>'


def measured_data(report,folder):
    """Load actual measured Lab from a saved certificate or verified C3 source."""
    data=report.get('measuredColours')
    if data:
        lab=data['lab'];rgb=data['rgb']
        if lab and isinstance(lab[0],(int,float)):lab=[lab]
        if rgb and isinstance(rgb[0],(int,float)):rgb=[rgb]
    else:
        source=report.get('sources',{}).get('c3_report')
        if not source:return None
        import hashlib
        root=Path(folder).resolve();path=(root/source['file']).resolve()
        if not path.is_relative_to(root) or hashlib.sha256(path.read_bytes()).hexdigest()!=source['sha256']:
            raise ValueError('Measured-colour source integrity mismatch.')
        patches=json.loads(path.read_text()).get('patches',[])
        lab=[p['measuredLab'] for p in patches if 'measuredLab' in p and p.get('role') not in ['repeat','paperwhite']]
        if not lab:return None
        import numpy as np,colour
        white=colour.CCS_ILLUMINANTS['CIE 1931 2 Degree Standard Observer']['D50']
        rgb=np.clip(colour.XYZ_to_sRGB(colour.Lab_to_XYZ(lab,white),illuminant=white,chromatic_adaptation_transform='Bradford'),0,1).tolist()
    if len(lab)!=len(rgb) or any(len(p)!=3 or not all(math.isfinite(x) for x in p) for p in lab):raise ValueError('Invalid measured Lab points.')
    if any(len(p)!=3 or not all(math.isfinite(x) and 0<=x<=1 for x in p) for p in rgb):raise ValueError('Invalid measured preview colours.')
    return dict(kind='points',vertices=lab,rgb=rgb,label='Measured print colours')


if __name__=='__main__':
    import sys
    folder=Path(sys.argv[1]);report=json.loads((folder/'final-report.json').read_text())
    data=measured_data(report,folder)
    text='<section><h2>Measured print colours - CIELAB D50</h2><p>Actual measurements. 2D selects points within the stated L* band; the point cloud is not a gamut boundary.</p>'+interactive(data)+'</section>' if data else '<section><h2>Measured print colours</h2><p>No measured Lab points available for this profile.</p></section>'
    (folder/'measured-colours.html').write_text(text)
