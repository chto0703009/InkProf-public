# Copyright (c) 2026 Christer Törnkvist.
# SPDX-License-Identifier: GPL-3.0-or-later
# Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
"""Inner Lab shell sampling with printable, forward-modelled device RGB."""
import numpy as np
from scipy.spatial import cKDTree
from gamut_surface import validate, forward_lookup


def shell_depth(points, vertices, triangles):
    """Exact Euclidean triangle distance and ray-parity inside test.

    Works with concave closed meshes; triangle winding is irrelevant.
    Boundary points are included. No convex hull or radial shrink is used.
    """
    validate(vertices, triangles)
    p = np.asarray(points, float).reshape(-1, 3)
    if not np.isfinite(p).all():
        raise ValueError('Invalid Lab candidates.')
    v = np.asarray(vertices, float)
    faces = np.asarray(triangles, int)
    edges = np.sort(np.concatenate([faces[:, [0, 1]], faces[:, [1, 2]], faces[:, [2, 0]]]), axis=1)
    if np.any(np.unique(edges, axis=0, return_counts=True)[1] != 2):
        raise ValueError('Shell sampling requires a closed gamut mesh.')
    distance2 = np.full(len(p), np.inf)
    crossings = np.zeros(len(p), dtype=int)
    direction = np.array([1., .371390676354, .529173612871])
    for a, b, c in v[faces]:
        ab, ac = b-a, c-a
        n = np.cross(ab, ac)
        nn = n @ n
        if nn <= 1e-20:
            raise ValueError('Degenerate gamut triangle.')
        ap = p-a
        signed = ap @ n
        projection = ap - signed[:, None] / nn * n
        aa, bb, cc = ab @ ab, ab @ ac, ac @ ac
        denom = aa*cc-bb*bb
        u = (cc*(projection @ ab)-bb*(projection @ ac))/denom
        w = (aa*(projection @ ac)-bb*(projection @ ab))/denom
        on_face = (u >= 0) & (w >= 0) & (u+w <= 1)
        distance2 = np.minimum(distance2, np.where(on_face, signed*signed/nn, np.inf))
        for start, end in ((a,b), (b,c), (c,a)):
            edge = end-start
            t = np.clip(((p-start) @ edge)/(edge @ edge), 0, 1)
            distance2 = np.minimum(distance2, np.sum((p-start-t[:, None]*edge)**2, axis=1))
        h = np.cross(direction, ac)
        determinant = ab @ h
        if abs(determinant) > 1e-12:
            ray_u = (ap @ h)/determinant
            q = np.cross(ap, ab)
            ray_v = (q @ direction)/determinant
            ray_t = (q @ ac)/determinant
            crossings += ((ray_u >= 0) & (ray_v >= 0) & (ray_u+ray_v <= 1) & (ray_t > 1e-9))
    depth = np.sqrt(distance2)
    return depth, ((crossings % 2) == 1) | (depth <= 1e-8)


def candidates(request, profile):
    thickness = float(request['shellThicknessDeltaE76'])
    spacing = float(request['minSpacingPercent'])
    maximum = request['maxPatches']
    if not np.isfinite([thickness, spacing, maximum]).all() or not 0 < thickness <= 50 or not 0 < spacing <= 20 or int(maximum) != maximum or not 1 <= maximum <= 1000:
        raise ValueError('Invalid shell thickness, spacing or patch budget.')
    surface = request['surface']
    if surface['profileSHA256'] != request['profileSHA256']:
        raise ValueError('Gamut mesh belongs to another ICC.')
    existing = np.asarray(request['existingRGBPercent'], float).reshape(-1, 3)
    if not np.isfinite(existing).all() or np.any((existing < 0) | (existing > 100)):
        raise ValueError('Invalid training RGB.')
    # Fixed seed and RGB16 quantisation make proposals reproducible.
    from scipy.stats import qmc
    rgb = qmc.Sobol(3, scramble=True, seed=42).random_base2(14)*100
    faces = np.array(np.meshgrid(*[np.linspace(0, 100, 17)]*2, indexing='ij')).reshape(2, -1).T
    boundary = []
    for axis in range(3):
        for side in (0, 100):
            rows = np.empty((len(faces), 3)); rows[:, axis] = side
            rows[:, [i for i in range(3) if i != axis]] = faces
            boundary.append(rows)
    rgb = np.unique(np.round(np.vstack([rgb, *boundary])/100*65535), axis=0)/65535*100
    if len(existing):
        keep = cKDTree(existing).query(rgb, p=np.inf)[0] >= spacing
        rgb = rgb[keep]
    lab = forward_lookup(request['xicclu'], profile, rgb/100)
    depth, inside = shell_depth(lab, surface['vertices'], surface['triangles'])
    boundary_mode = request.get('samplingMode') == 'boundary'
    keep = (depth <= thickness) if boundary_mode else inside & (depth <= thickness)
    if boundary_mode:
        depth = np.where(inside, depth, -depth)  # Negative: predicted outside the mesh.
    if request.get('samplingMode') == 'shell-region':
        region_radius = float(request['regionRadiusDeltaE76'])
        anchors = request['anchors']
        if isinstance(anchors, dict):
            anchors = [anchors]
        centres = np.asarray([a['lab'] for a in anchors], float).reshape(-1, 3)
        if not len(centres) or not np.isfinite(centres).all() or not np.isfinite(region_radius) or not 0 < region_radius <= 100:
            raise ValueError('Select surface areas and a finite Lab region radius in 0..100.')
        keep &= cKDTree(centres).query(lab)[0] <= region_radius
    rgb, lab, depth = rgb[keep], lab[keep], depth[keep]
    if not len(rgb):
        raise ValueError('No new shell patches remain. Increase shell thickness or reduce spacing.')
    training_lab = forward_lookup(request['xicclu'], profile, existing/100) if len(existing) else np.empty((0, 3))
    nearest = cKDTree(training_lab).query(lab)[0] if len(training_lab) else np.full(len(lab), np.inf)
    chosen = []
    for _ in range(min(int(maximum), len(rgb))):
        index = int(np.argmax(nearest))
        if nearest[index] < 0:
            break
        chosen.append(index)
        nearest = np.minimum(nearest, np.linalg.norm(lab-lab[index], axis=1))
        nearest[np.max(np.abs(rgb-rgb[index]), axis=1) < spacing] = -1
    return rgb[chosen].tolist(), lab[chosen], depth[chosen]
