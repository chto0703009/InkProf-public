# Copyright (c) 2026 Christer Törnkvist.
# SPDX-License-Identifier: GPL-3.0-or-later
# InkProf is free software under GNU GPL version 3 or later.
# Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
"""Synthetic blue-sky test image without third-party content.

Follows the same Lab path as analysis/sky_ramp.py (L* 70 at the bottom to 38
at the top, a*/b* from the fitted sky). Lab D50 -> XYZ -> Bradford D65 -> sRGB.
Writes a 16-bit and an 8-bit (no dithering) PNG with an embedded sRGB profile
and 300 ppi, plus a strip version with the b*-4 / sky / b*+4 paths side by side.
"""
import argparse, struct, sys, zlib
from pathlib import Path
import numpy as np
from PIL import Image, ImageCms
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'analysis'))
from sky_ramp import A_COEFF, B_COEFF, L_RANGE

D50 = np.array([0.9642, 1.0, 0.8249])
BRADFORD_D50_TO_D65 = np.array([[0.9555766, -0.0230393, 0.0631636],
                                [-0.0282895, 1.0099416, 0.0210077],
                                [0.0122982, -0.0204830, 1.3299098]])
XYZ_TO_SRGB = np.array([[3.2404542, -1.5371385, -0.4985314],
                        [-0.9692660, 1.8760108, 0.0415560],
                        [0.0556434, -0.2040259, 1.0572252]])


def lab_to_srgb(lab):
    L, a, b = np.moveaxis(lab, -1, 0)
    fy = (L + 16) / 116; fx = fy + a / 500; fz = fy - b / 200
    eps, kappa = 216 / 24389, 24389 / 27
    inv = lambda f: np.where(f ** 3 > eps, f ** 3, (116 * f - 16) / kappa)
    xyz = np.stack([inv(fx), np.where(L > kappa * eps, fy ** 3, L / kappa), inv(fz)], -1) * D50
    lin = xyz @ BRADFORD_D50_TO_D65.T @ XYZ_TO_SRGB.T
    # The b*-4 strip touches the sRGB boundary for L* < 38.5 (linear R >= -0.0009);
    # that is clipped. Anything further outside is an error.
    if (lin < -2e-3).any() or (lin > 1 + 2e-3).any():
        raise ValueError('Sky path leaves the sRGB gamut.')
    lin = np.clip(lin, 0, 1)
    return np.where(lin <= 0.0031308, 12.92 * lin, 1.055 * lin ** (1 / 2.4) - 0.055)


def sky_column(height, offset=0.0):
    L = np.linspace(L_RANGE[0], L_RANGE[1], height)  # row 0 = top = darkest
    return np.column_stack([L, np.polyval(A_COEFF, L), np.polyval(B_COEFF, L) + offset])


def write_png16(path, rgb01, icc, ppi):
    h, w, _ = rgb01.shape
    data = np.round(rgb01 * 65535).astype('>u2')
    raw = b''.join(b'\x00' + data[y].tobytes() for y in range(h))
    def chunk(kind, body):
        return struct.pack('>I', len(body)) + kind + body + struct.pack('>I', zlib.crc32(kind + body) & 0xffffffff)
    ppm = round(ppi / 0.0254)
    png = (b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('>IIBBBBB', w, h, 16, 2, 0, 0, 0)) +
           chunk(b'iCCP', b'sRGB\x00\x00' + zlib.compress(icc)) + chunk(b'pHYs', struct.pack('>IIB', ppm, ppm, 1)) +
           chunk(b'IDAT', zlib.compress(raw, 9)) + chunk(b'IEND', b''))
    Path(path).write_bytes(png)


def main(out, width, height, ppi):
    out = Path(out); out.mkdir(parents=True, exist_ok=True)
    icc = ImageCms.ImageCmsProfile(ImageCms.createProfile('sRGB')).tobytes()
    sky = np.repeat(lab_to_srgb(sky_column(height))[:, None, :], width, axis=1)
    strips = np.concatenate([np.repeat(lab_to_srgb(sky_column(height, o))[:, None, :], width // 3, axis=1)
                             for o in (-4.0, 0.0, 4.0)], axis=1)
    for name, img in (('sky-gradient', sky), ('sky-gradient-strips', strips)):
        write_png16(out / f'{name}-16bit.png', img, icc, ppi)
        Image.fromarray(np.round(img * 255).astype('uint8')).save(out / f'{name}-8bit.png', icc_profile=icc, dpi=(ppi, ppi))
    return out


if __name__ == '__main__':
    a = argparse.ArgumentParser(); a.add_argument('output'); a.add_argument('--width', type=int, default=2400)
    a.add_argument('--height', type=int, default=3000); a.add_argument('--ppi', type=int, default=300)
    v = a.parse_args(); print(main(v.output, v.width, v.height, v.ppi))
