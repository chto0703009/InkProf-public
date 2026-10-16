# Copyright (c) 2026 Christer Törnkvist.
# SPDX-License-Identifier: GPL-3.0-or-later
# InkProf is free software under GNU GPL version 3 or later.
# Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
"""Portable optional viewer of the current profile's fitting and C3 evidence."""
import hashlib
import html
import json
from pathlib import Path


def build(request, folder):
    import numpy as np
    import colour
    folder = Path(folder)
    digest = request['profileSHA256']
    if hashlib.sha256((folder/'profile.icc').read_bytes()).hexdigest() != digest:
        raise ValueError('Saved ICC does not match measurement viewer request.')
    groups, sources = [], []
    for key, label in [('fit', 'Profile fitting measurements'), ('verification', 'Current verification measurements')]:
        if not request.get(key):
            continue
        path = Path(request[key]); raw = path.read_bytes(); report = json.loads(raw)
        report_digest = report.get('profileSHA256')
        if key == 'verification':
            profiles = [s['sha256'] for s in report.get('sources', []) if Path(s.get('path', '')).suffix.lower() in ['.icc', '.icm']]
            report_digest = profiles[0] if len(profiles) == 1 else None
        if report_digest != digest:
            raise ValueError('Measurement report belongs to another ICC.')
        rgb_by_id = {}
        if key == 'verification' and request.get('verificationReference'):
            reference_path = Path(request['verificationReference'])
            reference_raw = reference_path.read_bytes()
            reference = json.loads(reference_raw)
            reference_hash = hashlib.sha256(reference_raw).hexdigest()
            if reference['printerProfile']['sha256'] != digest or not any(
                    s['sha256'] == reference_hash for s in report.get('sources', [])):
                raise ValueError('Verification reference integrity mismatch.')
            rgb_by_id = {str(p['id']): [x*100 for x in p['deviceRGB']] for p in reference['patches']}
        points = []
        for p in report.get('patches', []):
            lab = p.get('measuredLab')
            if lab is None:
                raise ValueError('Measured Lab missing from evidence.')
            if len(lab) != 3 or not all(np.isfinite(lab)):
                raise ValueError('Invalid measured Lab.')
            points.append(dict(lab=lab, id=str(p.get('sampleId', '')), coordinate=p.get('coordinate', ''),
                               referenceLab=p.get('desiredLab') if key == 'verification' else p.get('predictedLab'), role=p.get('role', 'fitting'), rgb=p.get('rgbPercent', rgb_by_id.get(str(p.get('sampleId', '')))), deltaE00=p.get('deltaE00')))
        labs = [p['lab'] for p in points]
        if labs:
            white = colour.CCS_ILLUMINANTS['CIE 1931 2 Degree Standard Observer']['D50']
            previews = np.clip(colour.XYZ_to_sRGB(colour.Lab_to_XYZ(labs, white), illuminant=white,
                                                chromatic_adaptation_transform='Bradford'), 0, 1).tolist()
            for p, rgb in zip(points, previews):
                p['preview'] = rgb
            for target, field in [('desiredPreview', 'desiredLab'), ('predictedPreview', 'predictedLab')]:
                for point, source in zip(points, report['patches']):
                    if source.get(field) is not None:
                        lab = source[field]
                        point[target] = np.clip(colour.XYZ_to_sRGB(colour.Lab_to_XYZ(lab, white),
                            illuminant=white, chromatic_adaptation_transform='Bradford'), 0, 1).tolist()
        groups.append(dict(key=key, label=label, points=points))
        sources.append(dict(group=key, sha256=hashlib.sha256(raw).hexdigest(), count=len(points)))
    data = dict(profileSHA256=digest, groups=groups, sources=sources, surface=None, defaultScope=request.get('scope', 'all'))
    surface_path = folder/'gamut-surface.json'
    if surface_path.exists():
        surface = json.loads(surface_path.read_text())
        if surface['profileSHA256'] != digest:
            raise ValueError('Gamut surface belongs to another ICC.')
        data['surface'] = {k: surface[k] for k in ['vertices', 'triangles']}
    payload = json.dumps(data, allow_nan=False, separators=(',', ':')).replace('<', '\\u003c')
    template = Path(__file__).with_name('certificate_measurements.html').read_text()
    viewer = template.replace('__DATA__', payload)
    (folder/'all-measurements.html').write_text(viewer)
    (folder/'all-measurements.json').write_text(json.dumps(data, allow_nan=False, indent=2))
    report_path = folder/'final-report.json'
    report = json.loads(report_path.read_text())
    report['measurementView'] = dict(file='all-measurements.html', data='all-measurements.json',
                                    profileSHA256=digest, sources=sources)
    report_path.write_text(json.dumps(report, ensure_ascii=False, indent=2))
    certificate = folder/'final-report.html'
    text = certificate.read_text()
    section = '<section><h2>3D measurements and compact patch comparison (Top 100 deviations with Delta E00 &gt; 1)</h2><p><a href="all-measurements.html">Open 3D and patch comparison</a>. Includes all available fitting measurements for this ICC and current verification measurements as separate groups. Choose all available groups or the latest group; the compact table lists Top 100 deviations with Delta E00 &gt; 1 before rounding. Other project measurements are excluded. The viewer travels with this delivery folder.</p></section>'
    selected = groups
    if data['defaultScope'] == 'latest':
        selected = [g for g in groups if g['key'] == ('verification' if any(g['key'] == 'verification' for g in groups) else 'fit')]
    rows = sorted([(g, p) for g in selected for p in g['points'] if p['deltaE00'] is not None and p['deltaE00'] > 1],
                  key=lambda item: item[1]['deltaE00'])[-100:]
    def chip(rgb):
        if rgb is None:
            return 'Unavailable'
        color = '#'+''.join(f'{round(c*255):02x}' for c in rgb)
        return f'<span style="display:inline-block;width:28px;height:16px;border:1px solid #888;background:{color};print-color-adjust:exact"></span>'
    compact = '<h3>Compact comparison — '+html.escape(data['defaultScope'])+' measurements</h3><p>Top 100 deviations with Delta E00 &gt; 1 before rounding. Fitting: model vs measured. Verification: measured vs desired. Diagnostic display threshold, not an acceptance or ISO limit.</p><table><thead><tr><th>Group</th><th>Reference Lab (L*, a*, b*)</th><th>Desired</th><th>Predicted</th><th>Measured</th><th>Delta E00</th></tr></thead><tbody>'
    for group, point in rows:
        compact += '<tr><td>'+html.escape(group['label'])+'</td><td>'+html.escape(', '.join(f'{x:.2f}' for x in point['referenceLab']) if point.get('referenceLab') is not None else 'Unavailable')+'</td>'
        compact += ''.join('<td>'+chip(point.get(k))+'</td>' for k in ['desiredPreview', 'predictedPreview', 'preview'])
        compact += f'<td style="text-align:right">{point["deltaE00"]:.3f}</td></tr>'
    compact += '</tbody></table><p>'+str(len(rows))+' selected patches above 1.000 (up to 100 largest, smallest first).</p>'
    # Detailed Lab values belong in the supplement, not the main certificate.
    (folder/'patch-comparison.html').write_text('<!doctype html><meta charset="utf-8">'+compact)
    section = section.replace('</section>', '<p><a href="patch-comparison.html">Patch comparison table</a></p></section>')
    certificate.write_text(text.replace('</html>', section+'</html>'))
    with (folder/'final-report.txt').open('a') as stream:
        stream.write('\nOptional interactive measurement viewer: all-measurements.html (HTML delivery folder).\n')
    return data


if __name__ == '__main__':
    import sys
    build(json.loads(Path(sys.argv[1]).read_text()), sys.argv[2])
