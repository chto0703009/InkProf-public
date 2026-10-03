# Copyright (c) 2026 Christer Törnkvist.
# SPDX-License-Identifier: GPL-3.0-or-later
# InkProf is free software under GNU GPL version 3 or later.
# Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
"""Certificate views of the verified shared RGB comparison samples.
Uses the existing interactive comparison viewer and a vector PDF projection.
"""
import hashlib
import html
import json
import math
from pathlib import Path
from reportlab.graphics.shapes import Drawing, Circle, Line, String
from reportlab.lib import colors


def load(folder, report):
    source = report.get('sources', {}).get('comparison')
    if not source:
        return None
    data = (Path(folder) / source['file']).read_bytes()
    if hashlib.sha256(data).hexdigest() != source['sha256']:
        raise ValueError('Comparison figure source checksum mismatch')
    comparison = json.loads(data)
    if comparison['profileSHA256']['current'] != report['profile']['sha256']:
        raise ValueError('Comparison figure belongs to a different current ICC')
    groups = [comparison['grid'][k] for k in ('previousLab', 'currentLab')]
    if not groups[0] or len(groups[0]) != len(groups[1]):
        raise ValueError('Comparison figure requires matching sample sets')
    for group in groups:
        for point in group:
            if len(point) != 3 or not all(isinstance(v, (float, int)) and math.isfinite(v) for v in point):
                raise ValueError('Invalid Lab sample in comparison figure')
    return groups


def interactive(groups, language='sv'):
    swedish = language == 'sv'
    label = '2D a*/b* vid valt L*' if swedish else '2D a*/b* at selected L*'
    width = 'Halvbredd' if swedish else 'Half-width'
    controls = f'''<p><label><input type="checkbox" id="slice" checked> {label}</label>
    <label>L*: <input id="lightness" type="range" min="0" max="100" value="50" step="1"><output id="level">50</output></label>
    <label>{width}: <input id="width" type="number" min="1" max="50" value="5"> L*</label></p>
    <p id="counts"></p><canvas id="view" width="900" height="460" style="max-width:100%;touch-action:none;background:#f3f6f8"></canvas>'''
    labels = dict(previous='föregående', current='aktuell', visible='Synliga provpunkter',
                  sparse='Provpunkter inom L*-intervallet; ett glest snitt betyder inte att utskrivbara färger saknas.',
                  all='Alla ljushetsnivåer visas.', rotate='3D Lab - dra för att rotera; L* ökar uppåt') if swedish else {}
    script = Path(__file__).with_name('profile_comparison_view.js').read_text(encoding='utf-8')
    return controls+'<script>(()=>{const groups='+json.dumps(groups,allow_nan=False)+';const viewLabels='+json.dumps(labels,ensure_ascii=False)+';\n'+script+'\n})();</script>'


def pdf_drawing(groups, language='sv'):
    """Orthographic Lab projection with three labelled axes; not a gamut surface."""
    w,h=480,320
    drawing=Drawing(w,h)
    angle=.6
    def raw(point):
        light,a,b=point
        return (a*math.cos(angle)-b*math.sin(angle),light*1.5+(a*math.sin(angle)+b*math.cos(angle))*.35)
    axis_points=[[0,0,0],[100,0,0],[0,110,0],[0,0,110]]
    points=[raw(p) for g in groups for p in g]+[raw(p) for p in axis_points]
    xs,ys=zip(*points);lo_x,hi_x=min(xs),max(xs);lo_y,hi_y=min(ys),max(ys)
    scale=min((w-90)/max(1,hi_x-lo_x),(h-70)/max(1,hi_y-lo_y))
    def project(point):
        x,y=raw(point)
        return 45+(x-lo_x)*scale,35+(y-lo_y)*scale
    origin=project(axis_points[0])
    for point,label in zip(axis_points[1:],['L*','a*','b*']):
        end=project(point)
        drawing.add(Line(*origin,*end,strokeColor=colors.HexColor('#667784'),strokeWidth=.6))
        drawing.add(String(end[0]+3,end[1]+3,label,fontSize=9))
    for group,colour in zip(groups,['#216bb0','#d67520']):
        for point in sorted(group,key=lambda p:p[0]):
            x,y=project(point)
            drawing.add(Circle(x,y,1.5,fillColor=colors.HexColor(colour),strokeColor=None,fillOpacity=.55))
    legend='Blå: föregående profil. Orange: aktuell profil.' if language=='sv' else 'Blue: previous profile. Orange: current profile.'
    drawing.add(String(12,8,legend,fontName='Helvetica',fontSize=9))
    return drawing
