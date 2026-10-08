# Copyright (c) 2026 Christer Törnkvist.
# SPDX-License-Identifier: GPL-3.0-or-later
# InkProf is free software under GNU GPL version 3 or later.
# Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
"""Shared colour arithmetic (numpy only): ICC D50 XYZ <-> Lab, CIEDE2000,
summary statistics and measurement-noise estimation from repeated patches."""
import math

import numpy as np

ICC_D50 = np.array([96.42, 100.0, 82.49])  # ICC PCS illuminant, XYZ * 100

def xyz_to_lab(xyz):
    t = np.asarray(xyz, dtype=float) / ICC_D50
    eps, kappa = 216 / 24389, 24389 / 27
    f = np.where(t > eps, np.cbrt(t), (kappa * t + 16) / 116)
    return np.stack([116 * f[..., 1] - 16, 500 * (f[..., 0] - f[..., 1]), 200 * (f[..., 1] - f[..., 2])], axis=-1)


def lab_to_xyz(lab):
    lab = np.asarray(lab, dtype=float)
    eps, kappa = 216 / 24389, 24389 / 27
    fy = (lab[..., 0] + 16) / 116; fx = fy + lab[..., 1] / 500; fz = fy - lab[..., 2] / 200
    inv = lambda f: np.where(f ** 3 > eps, f ** 3, (116 * f - 16) / kappa)
    yr = np.where(lab[..., 0] > kappa * eps, fy ** 3, lab[..., 0] / kappa)
    return np.stack([inv(fx), yr, inv(fz)], axis=-1) * ICC_D50


def delta_e00(lab1, lab2):
    """Vectorized CIEDE2000 (kL=kC=kH=1)."""
    L1, a1, b1 = np.moveaxis(np.asarray(lab1, dtype=float), -1, 0)
    L2, a2, b2 = np.moveaxis(np.asarray(lab2, dtype=float), -1, 0)
    Cm = (np.hypot(a1, b1) + np.hypot(a2, b2)) / 2
    G = 0.5 * (1 - np.sqrt(Cm ** 7 / (Cm ** 7 + 25.0 ** 7)))
    a1p, a2p = (1 + G) * a1, (1 + G) * a2
    C1p, C2p = np.hypot(a1p, b1), np.hypot(a2p, b2)
    h1p = np.where(C1p == 0, 0, np.degrees(np.arctan2(b1, a1p)) % 360)
    h2p = np.where(C2p == 0, 0, np.degrees(np.arctan2(b2, a2p)) % 360)
    dh = h2p - h1p
    dh = np.where(C1p * C2p == 0, 0, np.where(dh > 180, dh - 360, np.where(dh < -180, dh + 360, dh)))
    dH = 2 * np.sqrt(C1p * C2p) * np.sin(np.radians(dh / 2))
    Lpm, Cpm = (L1 + L2) / 2, (C1p + C2p) / 2
    hs = h1p + h2p
    hpm = np.where(C1p * C2p == 0, hs, np.where(np.abs(h1p - h2p) <= 180, hs / 2, np.where(hs < 360, (hs + 360) / 2, (hs - 360) / 2)))
    T = (1 - 0.17 * np.cos(np.radians(hpm - 30)) + 0.24 * np.cos(np.radians(2 * hpm))
         + 0.32 * np.cos(np.radians(3 * hpm + 6)) - 0.20 * np.cos(np.radians(4 * hpm - 63)))
    dtheta = 30 * np.exp(-((hpm - 275) / 25) ** 2)
    RC = 2 * np.sqrt(Cpm ** 7 / (Cpm ** 7 + 25.0 ** 7))
    SL = 1 + 0.015 * (Lpm - 50) ** 2 / np.sqrt(20 + (Lpm - 50) ** 2)
    SC = 1 + 0.045 * Cpm; SH = 1 + 0.015 * Cpm * T
    RT = -np.sin(np.radians(2 * dtheta)) * RC
    dL, dC = L2 - L1, C2p - C1p
    return np.sqrt((dL / SL) ** 2 + (dC / SC) ** 2 + (dH / SH) ** 2 + RT * (dC / SC) * (dH / SH))


def summary(values):
    v = np.asarray(values, dtype=float)
    if not v.size:
        return dict(count=0, mean=None, median=None, p95=None, max=None)
    return dict(count=int(v.size), mean=float(v.mean()), median=float(np.median(v)), p95=float(np.percentile(v, 95)), max=float(v.max()))


def groups_by_rgb(rgb, decimals=4):
    """Repeats of the same device RGB (0..1) form one group; compared at 1e-4 %."""
    keys = np.round(np.asarray(rgb, dtype=float) * 100, decimals)
    _, inverse = np.unique(keys, axis=0, return_inverse=True)
    return inverse.ravel()


def estimate_noise(rgb, lab, decimals=4):
    """Noise of one reading (rgb: device RGB 0..1; lab: one row per patch) from patches repeated at different chart positions.

    For two independent readings of the same colour E||x1-x2||^2 = 2 sigma^2, so
    sigma^2 (summed over L*, a*, b*) = mean pair ||dLab||^2 / 2. With more than two
    repeats every pair within the group is used, weighted so each group counts once.
    This captures print non-uniformity + position + instrument, which is what a
    profile should not follow. Only repeats inside the fitting set are used.
    """
    groups = groups_by_rgb(rgb, decimals)
    lab = np.asarray(lab, dtype=float)
    pair_sq, pair_de, group_sq, components = [], [], [], []
    for g in np.unique(groups):
        idx = np.where(groups == g)[0]
        if len(idx) < 2:
            continue
        sq = []
        for i in range(len(idx)):
            for j in range(i + 1, len(idx)):
                d = lab[idx[i]] - lab[idx[j]]
                sq.append(float(d @ d)); components.append(np.abs(d))
                pair_de.append(float(delta_e00(lab[idx[i]], lab[idx[j]])))
        pair_sq += sq; group_sq.append(np.mean(sq))
    if not group_sq:
        return dict(groups=0, pairs=0)
    sigma2 = float(np.mean(group_sq) / 2)
    comp = np.array(components) / math.sqrt(2)  # per-reading absolute deviation per component
    return dict(groups=len(group_sq), pairs=len(pair_sq), sigmaLabSquared=sigma2, sigmaLab=math.sqrt(sigma2),
                pairDeltaE00=summary(pair_de), perComponentMeanAbsDeviation=dict(L=float(comp[:, 0].mean()),
                a=float(comp[:, 1].mean()), b=float(comp[:, 2].mean())),
                basis='Patches with identical device RGB at different chart positions; sigma^2 = mean pair |dLab|^2 / 2')


def argyll_avgdev_suggestion(noise):
    """Approximate colprof -r from the per-reading mean absolute deviation (Lab units ~ % of 0-100)."""
    if not noise.get('pairs'):
        return None
    value = float(np.mean(list(noise['perComponentMeanAbsDeviation'].values())))
    return dict(estimatePercent=value, suggestedPercent=float(min(2.0, max(0.1, round(value, 2)))), floor=0.1, ceiling=2.0,
                argyllDefault=0.5,
                caveat='Approximate: treats one Lab unit as one percent of the PCS range. colprof -r is not lambda and is applied inside RSPL with its own scaling.')
