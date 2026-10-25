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
    inherited = np.asarray(request.get('inheritedRGBPercent', []), float).reshape(-1, 3)
    if not np.isfinite(inherited).all() or np.any((inherited < 0) | (inherited > 100)):
        raise ValueError('Invalid inherited target RGB.')
    existing = np.asarray(request['existingRGBPercent'], float).reshape(-1, 3)
    retained = []
    for rgb in inherited:
        occupied = np.vstack([existing, np.asarray(retained).reshape(-1, 3)])
        # Keep exact parent RGB16 colours, excluding measured and exact duplicate RGB.
        if len(occupied) and np.any(np.max(np.abs(occupied-rgb), axis=1) < .0008):
            continue
        retained.append(rgb.tolist())
    extended_request = dict(request, existingRGBPercent=np.vstack([existing, np.asarray(retained).reshape(-1, 3)]).tolist())
    shell = request.get('samplingMode', 'neighbour') in ('shell', 'shell-region', 'boundary')
    if shell:
        from gamut_shell import candidates as shell_candidates
        rows, lab, depths = shell_candidates(extended_request, profile)
        sources = [0] * len(rows)
    else:
        rows, sources = candidates(request['anchorRGBPercent'], extended_request['existingRGBPercent'],
                                   request['radiusPercent'], request['minSpacingPercent'], request['maxPatches'])
    if not rows:
        raise ValueError('No new patches remain. Increase the radius or reduce the minimum spacing.')
    if not shell:
        lab = forward_lookup(request['xicclu'], profile, np.asarray(rows) / 100)
    white = colour.CCS_ILLUMINANTS['CIE 1931 2 Degree Standard Observer']['D50']
    preview = np.clip(colour.XYZ_to_sRGB(colour.Lab_to_XYZ(lab, illuminant=white), illuminant=white,
                                        chromatic_adaptation_transform='Bradford'), 0, 1)
    if digest(profile) != request['profileSHA256']:
        raise ValueError('ICC changed during patch calculation.')
    patches = [dict(patchId=f'GAM-{i+1:04d}', rgbPercent=rgb, anchorIndex=source, predictedLab=pred.tolist(),
                    previewRGB=colour_rgb.tolist(), kind='gamut-shell' if shell else 'gamut-neighbour')
               for i, (rgb, source, pred, colour_rgb) in enumerate(zip(rows, sources, lab, preview))]
    result = dict(schemaVersion=1, documentType='inkprof.gamut-refinement', status='proposal-review-required',
                  sourceProfileSHA256=request['profileSHA256'], anchors=request['anchors'],
                  parameters=dict(radiusPercent=request['radiusPercent'], minSpacingPercent=request['minSpacingPercent'],
                                  maxPatches=request['maxPatches']), candidates=patches,
                  caveat='User-directed sampling, not measured error feedback. Selected gamut vertices are associated with approximate nearest forward RGB samples; extra measurements cannot extend the physical printer gamut.')
    if shell:
        for patch, depth in zip(patches, depths):
            patch['surfaceDistanceDeltaE76'] = float(depth)
        result['samplingMode'] = request['samplingMode']
        if request['samplingMode'] == 'shell-region':
            result['parameters']['regionRadiusDeltaE76'] = request['regionRadiusDeltaE76']
        result['parameters']['shellThicknessDeltaE76'] = request['shellThicknessDeltaE76']
        result['parameters']['candidateSeed'] = 42
        result['surface'] = request['surface']
        result['caveat'] = 'Forward ICC predictions within the inner Lab shell, not measured print errors. Extra measurements cannot extend physical gamut.'
        if request['samplingMode'] == 'boundary':
            result['caveat'] = 'Printable RGB exploration on either side of the current mesh; negative signed distance means predicted outside. No physical gamut expansion is guaranteed.'
            result['parameters']['surfaceDistanceConvention'] = 'positive inside, negative outside'
            for patch in patches:
                patch['kind'] = 'gamut-boundary'
                patch['predictedOutsideMesh'] = patch['surfaceDistanceDeltaE76'] < 0
    if 'inheritedRGBPercent' in request:
        inherited_lab = forward_lookup(request['xicclu'], profile, np.asarray(retained).reshape(-1, 3)/100) if retained else np.empty((0, 3))
        inherited_preview = np.clip(colour.XYZ_to_sRGB(colour.Lab_to_XYZ(inherited_lab, illuminant=white), illuminant=white,
                                                     chromatic_adaptation_transform='Bradford'), 0, 1)
        inherited_patches = [dict(patchId=f'EXT-{i+1:04d}', rgbPercent=rgb, anchorIndex=0,
                                  predictedLab=pred.tolist(), previewRGB=preview_rgb.tolist(), kind='inherited-target')
                             for i, (rgb, pred, preview_rgb) in enumerate(zip(retained, inherited_lab, inherited_preview))]
        if shell and retained:
            from gamut_shell import shell_depth
            distances, inside = shell_depth(inherited_lab, request['surface']['vertices'], request['surface']['triangles'])
            for item, distance, is_inside in zip(inherited_patches, distances, inside):
                item['surfaceDistanceDeltaE76'] = float(distance if is_inside else -distance)
                if request['samplingMode'] == 'boundary':
                    item['predictedOutsideMesh'] = not bool(is_inside)
        result['inheritedCandidates'] = inherited_patches
        result['extensionCounts'] = dict(parentCount=len(inherited), retainedCount=len(retained), excludedMeasuredOrDuplicate=len(inherited)-len(retained))
    if digest(profile) != request['profileSHA256']:
        raise ValueError('ICC changed during target extension.')
    folder = Path(folder); folder.mkdir(parents=True)
    (folder / 'proposal.json').write_text(json.dumps(result, indent=2, allow_nan=False))
    return result


if __name__ == '__main__':
    import sys
    run(json.loads(Path(sys.argv[1]).read_text()), sys.argv[2])
