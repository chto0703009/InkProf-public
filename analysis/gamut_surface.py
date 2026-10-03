# Copyright (c) 2026 Christer Törnkvist.
# SPDX-License-Identifier: GPL-3.0-or-later
# InkProf is free software under GNU GPL version 3 or later.
# Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
"""ICC-derived Argyll surface; independent of measured patch clouds."""
import hashlib
import html
import json
import math
from pathlib import Path
import shutil
import subprocess
import tempfile


def digest(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def parse_gam(text):
    blocks = []
    active = None
    for line in text.splitlines():
        line = line.strip()
        if line == 'BEGIN_DATA':
            active = []
        elif line == 'END_DATA':
            blocks.append(active)
            active = None
        elif active is not None and line:
            active.append(line.split())
    if len(blocks) != 2 or not blocks[0] or not blocks[1] or 'COLOR_REP "LAB"' not in text:
        raise ValueError('Expected a Lab GAM surface with vertices and triangles.')
    vertices = []
    for i, row in enumerate(blocks[0]):
        if len(row) != 4 or int(row[0]) != i:
            raise ValueError('Invalid GAM vertex index.')
        vertices.append([float(x) for x in row[1:]])
    triangles = [[int(x) for x in row] for row in blocks[1]]
    validate(vertices, triangles)
    return vertices, triangles


def validate(vertices, triangles):
    if not vertices or not triangles or any(len(v) != 3 or not all(math.isfinite(x) for x in v) for v in vertices):
        raise ValueError('Invalid gamut vertices.')
    if any(len(t) != 3 or len(set(t)) != 3 or any(type(i) is not int or i < 0 or i >= len(vertices) for i in t) for t in triangles):
        raise ValueError('Invalid gamut triangles.')


def generate(profile, folder, executable):
    import numpy as np
    import colour
    profile, folder = Path(profile).resolve(), Path(folder)
    folder.mkdir(parents=True, exist_ok=True)
    sha = digest(profile)
    with tempfile.TemporaryDirectory(prefix='inkprof-gamut-') as work:
        copy = Path(work) / 'profile.icc'
        shutil.copyfile(profile, copy)
        result = subprocess.run([str(executable), '-v', '-d', '5', '-ff', '-ia', '-pl', str(copy)], capture_output=True, text=True, timeout=180)
        if result.returncode:
            raise RuntimeError('Argyll iccgamut could not construct this profile surface: '+(result.stdout+result.stderr)[-1200:])
        vertices, triangles = parse_gam(copy.with_suffix('.gam').read_text())
        if digest(profile) != sha or digest(copy) != sha:
            raise ValueError('ICC changed during gamut calculation.')
        shutil.copyfile(copy.with_suffix('.gam'), folder/'gamut-surface.gam')
        (folder/'gamut-surface.log').write_text(result.stdout+result.stderr)
    white = colour.CCS_ILLUMINANTS['CIE 1931 2 Degree Standard Observer']['D50']
    xyz = colour.Lab_to_XYZ(np.asarray(vertices), illuminant=white)
    rgb = np.clip(colour.XYZ_to_sRGB(xyz, illuminant=white, chromatic_adaptation_transform='Bradford'), 0, 1)
    version = subprocess.run([str(executable), '-?'], capture_output=True, text=True, timeout=10)
    data = dict(schemaVersion=1, documentType='inkprof.gamut-surface', profileSHA256=sha,
                method='Argyll iccgamut forward A2B, absolute colorimetric, CIELAB D50',
                detail=5, toolVersion=(version.stdout+version.stderr)[:600], vertices=vertices, triangles=triangles, rgb=rgb.tolist())
    path = folder/'gamut-surface.json'
    path.write_text(json.dumps(data, allow_nan=False))
    return dict(status='available', file=path.name, sha256=digest(path), profileSHA256=sha)


def load(folder, report):
    ref = report.get('gamut', {})
    if ref.get('status') != 'available':
        return None
    folder = Path(folder).resolve()
    path = (folder/ref['file']).resolve()
    if not path.is_relative_to(folder) or digest(path) != ref['sha256']:
        raise ValueError('Gamut file integrity mismatch.')
    data = json.loads(path.read_text())
    if data['profileSHA256'] != report['profile']['sha256'] or ref['profileSHA256'] != data['profileSHA256']:
        raise ValueError('Gamut belongs to another ICC profile.')
    validate(data['vertices'], data['triangles'])
    if len(data['rgb']) != len(data['vertices']) or any(len(v) != 3 or any(not math.isfinite(x) or x < 0 or x > 1 for x in v) for v in data['rgb']):
        raise ValueError('Invalid gamut preview colours.')
    return data


def caption(language='sv'):
    if language == 'en':
        return 'Predicted ICC gamut surface in CIELAB D50, calculated from the forward A2B table (absolute colorimetric). Surface detail approximately 5 Delta E; not an accuracy limit. Display colours are clipped sRGB previews. This is not a new measurement or a quality score.'
    return 'ICC-profilens beräknade gamut i CIELAB D50, från framåttabellen A2B (absolut kolorimetriskt). Ytdetalj cirka 5 Delta E; detta är ingen noggrannhetsgräns. Skärmfärgerna är klippta sRGB-förhandsvisningar. Figuren är inte en ny mätning eller ett kvalitetsbetyg.'


def interactive(data, language='sv'):
    if not data:
        return ''
    label = 'Rotate automatically; drag to turn' if language == 'en' else 'Rotera automatiskt; dra för att vrida'
    payload = json.dumps(data, separators=(',', ':')).replace('<', '\\u003c')
    script = (Path(__file__).with_name('gamut_view.js')).read_text()
    return '<div class="gamut-view"><label><input type="checkbox" checked> '+label+'</label><canvas width="850" height="520" style="width:100%;max-height:520px;touch-action:none" aria-label="ICC gamut CIELAB D50"></canvas><script type="application/json">'+payload+'</script></div><script>'+script+'</script>'


def pdf_drawing(data, language='sv'):
    from reportlab.graphics.shapes import Drawing, Polygon, String, Line
    from reportlab.lib.colors import Color
    d = Drawing(480, 330)
    angle = .65
    def project(v):
        l, a, b = v
        return (240+1.5*(a*math.cos(angle)-b*math.sin(angle)), 70+1.9*l+.45*(a*math.sin(angle)+b*math.cos(angle)), a*math.sin(angle)+b*math.cos(angle))
    points = [project(v) for v in data['vertices']]
    for tri in sorted(data['triangles'], key=lambda t: sum(points[i][2] for i in t), reverse=True):
        rgb = [sum(data['rgb'][i][c] for i in tri)/3 for c in range(3)]
        d.add(Polygon([n for i in tri for n in points[i][:2]], fillColor=Color(*rgb), strokeColor=None))
    for end, label in [([0,110,0],'a*'),([0,0,110],'b*'),([110,0,0],'L*')]:
        start=project([0,0,0]); stop=project(end)
        d.add(Line(*start[:2],*stop[:2],strokeColor=Color(.2,.25,.3)))
        d.add(String(stop[0]+3,stop[1]+3,label,fontSize=10))
    d.add(String(8,10,'CIELAB D50 | A2B | absolute colorimetric',fontSize=9))
    return d


if __name__ == '__main__':
    import sys
    ref = generate(sys.argv[1], sys.argv[2], sys.argv[3])
    (Path(sys.argv[2])/'gamut-reference.json').write_text(json.dumps(ref))
    data = load(sys.argv[2], dict(gamut=ref, profile=dict(sha256=ref['profileSHA256'])))
    (Path(sys.argv[2])/'gamut-view.html').write_text('<section><h2>ICC gamut — CIELAB D50</h2><p>'+html.escape(caption())+'</p>'+interactive(data)+'</section>')
