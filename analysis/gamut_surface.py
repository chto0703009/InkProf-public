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


def device_mapping(profile, executable, vertices):
    """Associate mesh vertices with known forward RGB samples, never inverse RGB.

    The Argyll envelope has no source RGB. Its vertices may not be reachable
    exactly, so retain the sampled Lab and the distance instead of claiming an
    exact inverse or using the clipped display colour as printer RGB.
    """
    import numpy as np
    from scipy.spatial import cKDTree
    levels = np.linspace(0, 1, 65)
    a, b = np.meshgrid(levels, levels, indexing='ij')
    faces = []
    for axis in range(3):
        for side in (0., 1.):
            face = np.empty((a.size, 3))
            face[:, axis] = side
            face[:, [i for i in range(3) if i != axis]] = np.column_stack([a.ravel(), b.ravel()])
            faces.append(face)
    # Interior extrema are possible; include a coarse full-cube grid too.
    interior = np.array(np.meshgrid(*[np.linspace(0, 1, 17)] * 3, indexing='ij')).reshape(3, -1).T
    rgb = np.unique(np.vstack(faces + [interior]), axis=0)
    lab = forward_lookup(executable, profile, rgb)
    distance, index = cKDTree(lab).query(np.asarray(vertices))
    return dict(method='Nearest sampled absolute A2B Lab; 65-level RGB faces plus 17-level interior grid',
                approximate=True, rgb=rgb[index].tolist(), lab=lab[index].tolist(),
                distanceDeltaE76=distance.tolist(), sampleCount=len(rgb))


def forward_lookup(executable, profile, rgb):
    import numpy as np
    values = np.asarray(rgb, dtype=float)
    result = subprocess.run([str(executable), '-v0', '-ff', '-ia', '-pl', str(profile)],
                            input=''.join(' '.join(f'{x:.10f}' for x in row) + '\n' for row in values),
                            capture_output=True, text=True, timeout=180)
    if result.returncode:
        raise ValueError('Forward RGB lookup failed: ' + (result.stderr + result.stdout)[-1200:])
    lab = np.asarray([line.split()[:3] for line in result.stdout.splitlines() if line.strip()], dtype=float)
    if lab.shape != values.shape or not np.isfinite(lab).all():
        raise ValueError('Invalid forward RGB lookup output.')
    return lab


def generate(profile, folder, executable, include_device_rgb=False):
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
    if include_device_rgb:
        lookup = Path(executable).with_name('xicclu' + Path(executable).suffix)
        data['deviceMapping'] = device_mapping(profile, lookup, vertices)
        if digest(profile) != sha:
            raise ValueError('ICC changed during device RGB mapping.')
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


def slice_segments(data, level=50):
    """Intersect mesh triangles with an exact constant-L* plane, without a hull."""
    result=[];seen=set();eps=1e-9
    for tri in data['triangles']:
        hits=[]
        for i,j in zip(tri,tri[1:]+tri[:1]):
            a,b=data['vertices'][i],data['vertices'][j]
            if abs(a[0]-level)<eps and abs(b[0]-level)<eps:
                hits.extend([a[1:],b[1:]])
            elif (a[0]-level)*(b[0]-level)<=0 and abs(b[0]-a[0])>eps:
                t=(level-a[0])/(b[0]-a[0]);hits.append([a[k]+t*(b[k]-a[k]) for k in [1,2]])
        unique=[]
        for h in hits:
            if not any(sum((x-y)**2 for x,y in zip(h,q))<eps**2 for q in unique):unique.append(h)
        pairs=[(unique[0],unique[1])] if len(unique)==2 else list(zip(unique,unique[1:]+unique[:1])) if len(unique)>2 else []
        rgb=[sum(data['rgb'][i][c] for i in tri)/3 for c in range(3)]
        for a,b in pairs:
            key=tuple(sorted([tuple(round(x,8) for x in a),tuple(round(x,8) for x in b)]))
            if key not in seen:result.append((a,b,rgb));seen.add(key)
    return result


def interactive(data, language='en'):
    if not data:return ''
    from lab_views import interactive as view
    return view(dict(data,kind='surface',label='ICC-predicted gamut'))


def pdf_drawing(data, language='en'):
    from reportlab.graphics.shapes import Line,String
    from reportlab.lib.colors import Color
    from lab_views import plane
    extent=max([20]+[abs(v) for p in data['vertices'] for v in p[1:]])
    d,project=plane(extent,'ICC gamut | exact L* = 50 slice')
    segments=slice_segments(data,50)
    for a,b,rgb in segments:
        d.add(Line(*project(*a),*project(*b),strokeColor=Color(*rgb),strokeWidth=2))
    if not segments:d.add(String(110,180,'No gamut intersection at L* = 50.',fontSize=11))
    d.add(String(12,6,'CIELAB D50 | A2B | absolute colorimetric | ICC prediction',fontSize=9))
    return d


if __name__ == '__main__':
    import sys
    ref = generate(sys.argv[1], sys.argv[2], sys.argv[3], '--device-rgb' in sys.argv[4:])
    (Path(sys.argv[2])/'gamut-reference.json').write_text(json.dumps(ref))
    data = load(sys.argv[2], dict(gamut=ref, profile=dict(sha256=ref['profileSHA256'])))
    (Path(sys.argv[2])/'gamut-view.html').write_text('<section><h2>ICC gamut — CIELAB D50</h2><p>'+html.escape(caption("en"))+'</p>'+interactive(data,"en")+'</section>')
