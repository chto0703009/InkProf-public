# Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
# Copyright (c) 2026 Christer Törnkvist.
# SPDX-License-Identifier: GPL-3.0-or-later
"""Render a text-free cover illustration from an existing ICC gamut mesh."""
import json
import sys
from pathlib import Path
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from mpl_toolkits.mplot3d.art3d import Poly3DCollection
import numpy as np

data = json.loads(Path(sys.argv[1]).read_text())
vertices = np.asarray(data['vertices'])[:, [1, 2, 0]]
triangles = np.asarray(data['triangles'])
rgb = np.asarray(data['rgb'])
figure = plt.figure(figsize=(8, 6), facecolor='white')
axes = figure.add_subplot(111, projection='3d')
axes.add_collection3d(Poly3DCollection(vertices[triangles],
    facecolors=rgb[triangles].mean(axis=1), edgecolors='none', linewidth=0))
axes.auto_scale_xyz(vertices[:, 0], vertices[:, 1], vertices[:, 2])
axes.set_box_aspect(np.ptp(vertices, axis=0), zoom=1.6)
axes.view_init(elev=22, azim=-60)
axes.set_axis_off()
figure.subplots_adjust(0, 0, 1, 1)
figure.savefig(Path(__file__).parent/'examples/cover-gamut.png', dpi=250,
               bbox_inches='tight', pad_inches=0)
