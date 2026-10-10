# Copyright (c) 2026 Christer Törnkvist.
# SPDX-License-Identifier: GPL-3.0-or-later
# Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
"""Device-RGB neighbourhoods around user-selected forward gamut samples."""
import json
from pathlib import Path
import numpy as np
from gamut_surface import digest, forward_lookup


def candidates(anchors, existing, radius=3., spacing=1., maximum=100):
    anchors = np.asarray(anchors, dtype=float).reshape(-1, 3)
    existing = np.asarray(existing, dtype=float).reshape(-1, 3)
    if not len(anchors) or not np.isfinite(anchors).all() or np.any((anchors < 0) | (anchors > 100)):
        raise ValueError('Select finite device RGB anchors in 0..100.')
    if not np.isfinite(existing).all() or np.any((existing < 0) | (existing > 100)):
        raise ValueError('Invalid training RGB.')
    if not np.isfinite([radius, spacing, maximum]).all() or not 0 < radius <= 20 or not 0 < spacing <= 20 or not 1 <= maximum <= 1000 or int(maximum) != maximum:
        raise ValueError('Invalid radius, spacing or patch budget.')
    offsets = np.array(np.meshgrid(*[[-1., 0., 1.]] * 3, indexing='ij')).reshape(3, -1).T
    offsets = offsets[np.argsort(np.linalg.norm(offsets, axis=1), kind='stable')]
    rows, sources = [], []
    # Round-robin: every selected region gets a chance before the budget fills.
    for offset in offsets:
        for i, anchor in enumerate(anchors):
            rgb = np.round(np.clip(anchor + offset * radius, 0, 100) / 100 * 65535) / 65535 * 100
            occupied = np.vstack([existing, np.asarray(rows).reshape(-1, 3)])
            if len(occupied) and np.any(np.max(np.abs(occupied - rgb), axis=1) < spacing):
                continue
            rows.append(rgb.tolist()); sources.append(i + 1)
            if len(rows) >= maximum:
                return rows, sources
    return rows, sources


def run(request, folder):
    import colour
    profile = Path(request['profile'])
    if digest(profile) != request['profileSHA256']:
        raise ValueError('Selected ICC changed.')
    rows, sources = candidates(request['anchorRGBPercent'], request['existingRGBPercent'],
                               request['radiusPercent'], request['minSpacingPercent'], request['maxPatches'])
    if not rows:
        raise ValueError('No new patches remain. Increase the radius or reduce the minimum spacing.')
    lab = forward_lookup(request['xicclu'], profile, np.asarray(rows) / 100)
    white = colour.CCS_ILLUMINANTS['CIE 1931 2 Degree Standard Observer']['D50']
    preview = np.clip(colour.XYZ_to_sRGB(colour.Lab_to_XYZ(lab, illuminant=white), illuminant=white,
                                        chromatic_adaptation_transform='Bradford'), 0, 1)
    if digest(profile) != request['profileSHA256']:
        raise ValueError('ICC changed during patch calculation.')
    patches = [dict(patchId=f'GAM-{i+1:04d}', rgbPercent=rgb, anchorIndex=source, predictedLab=pred.tolist(),
                    previewRGB=colour_rgb.tolist(), kind='gamut-neighbour')
               for i, (rgb, source, pred, colour_rgb) in enumerate(zip(rows, sources, lab, preview))]
    result = dict(schemaVersion=1, documentType='inkprof.gamut-refinement', status='proposal-review-required',
                  sourceProfileSHA256=request['profileSHA256'], anchors=request['anchors'],
                  parameters=dict(radiusPercent=request['radiusPercent'], minSpacingPercent=request['minSpacingPercent'],
                                  maxPatches=request['maxPatches']), candidates=patches,
                  caveat='User-directed sampling, not measured error feedback. Selected gamut vertices are associated with approximate nearest forward RGB samples; extra measurements cannot extend the physical printer gamut.')
    folder = Path(folder); folder.mkdir(parents=True)
    (folder / 'proposal.json').write_text(json.dumps(result, indent=2, allow_nan=False))
    return result


if __name__ == '__main__':
    import sys
    run(json.loads(Path(sys.argv[1]).read_text()), sys.argv[2])
