# Copyright (c) 2026 Christer Törnkvist.
# SPDX-License-Identifier: GPL-3.0-or-later
# InkProf is free software under GNU GPL version 3 or later.
# Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
"""Certificate views of the verified shared RGB comparison samples.
Uses the existing interactive comparison viewer and a vector PDF projection.
"""
import hashlib
import json
import math
from pathlib import Path
from reportlab.graphics.shapes import Drawing, Circle, Line, String
from reportlab.lib import colors


class ComparisonGroups(list):
    pass


def iteration_labels(groups, language):
    values=getattr(groups,'iterations',(None,None))
    fallback=('previous profile','current profile') if language!='sv' else ('föregående profil','aktuell profil')
    return [f'Iteration {v}' if v is not None else fallback[i] for i,v in enumerate(values)]


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
    result=ComparisonGroups(groups)
    result.iterations=(comparison.get('previousIteration'),comparison.get('currentIteration'))
    return result


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
    previous,current=iteration_labels(groups,language)
    labels.update(previous=previous,current=current)
    script = Path(__file__).with_name('profile_comparison_view.js').read_text(encoding='utf-8')
    return controls+'<script>(()=>{const groups='+json.dumps(groups,allow_nan=False)+';const viewLabels='+json.dumps(labels,ensure_ascii=False)+';\n'+script+'\n})();</script>'


def pdf_drawing(groups, language='sv'):
    """Matched profile predictions in the a*/b* plane, L*=50 +/-5."""
    from lab_views import plane
    extent=max([20]+[abs(v) for g in groups for p in g for v in p[1:]])
    drawing,project=plane(extent,'Profile predictions | L* = 50 +/- 5')
    for group,colour in zip(groups,['#216bb0','#d67520']):
        for point in group:
            if abs(point[0]-50)<=5:
                x,y=project(point[1],point[2]);drawing.add(Circle(x,y,1.8,fillColor=colors.HexColor(colour),strokeColor=None))
    previous,current=iteration_labels(groups,language)
    drawing.add(String(12,6,f'Blue: {previous}. Orange: {current}. Predictions, not measurements.',fontSize=9))
    return drawing
