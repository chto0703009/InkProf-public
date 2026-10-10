# Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
# Copyright (c) 2026 Christer Törnkvist.
# SPDX-License-Identifier: GPL-3.0-or-later
"""Portable sRGB gradient preview, proofed through the delivered printer ICC."""
import argparse
import hashlib
import json
from pathlib import Path
from PIL import Image, ImageCms


def create(profile, destination):
    profile, destination = Path(profile), Path(destination)
    destination.mkdir(parents=True, exist_ok=True)
    width, band = 1536, 96
    # Neutral, primaries, secondaries and a photographic blue-sky ramp.
    endpoints = [((0, 0, 0), (255, 255, 255)),
                 ((0, 0, 0), (255, 0, 0)), ((0, 0, 0), (0, 255, 0)),
                 ((0, 0, 0), (0, 0, 255)), ((0, 0, 0), (0, 255, 255)),
                 ((0, 0, 0), (255, 0, 255)), ((0, 0, 0), (255, 255, 0)),
                 ((30, 70, 135), (170, 210, 245))]
    original = Image.new('RGB', (width, band * len(endpoints)))
    pixels = original.load()
    for row, (start, end) in enumerate(endpoints):
        for x in range(width):
            colour = tuple(round(a + (b - a) * x / (width - 1)) for a, b in zip(start, end))
            for y in range(row * band, (row + 1) * band):
                pixels[x, y] = colour
    srgb = ImageCms.ImageCmsProfile(ImageCms.createProfile('sRGB'))
    original.save(destination / "gradients-original.jpg", quality=100, subsampling=0, icc_profile=srgb.tobytes())
    try:
        transform = ImageCms.buildProofTransformFromOpenProfiles(
            srgb, srgb, ImageCms.getOpenProfile(str(profile)), 'RGB', 'RGB',
            renderingIntent=1, proofRenderingIntent=1,
            flags=ImageCms.Flags.SOFTPROOFING | ImageCms.Flags.BLACKPOINTCOMPENSATION)
    except ImageCms.PyCMSError:
        metadata = dict(documentType='inkprof.gradient-soft-proof', available=False,
                        profileSHA256=hashlib.sha256(profile.read_bytes()).hexdigest(),
                        physicalMeasurement=False, reason='ICC does not support this proof transform')
        (destination / 'gradients.json').write_text(json.dumps(metadata, indent=2), encoding='utf-8')
        (destination / 'gradients.html').write_text('<!doctype html><html lang=sv><meta charset=utf-8><title>InkProf gradienter</title><h1>Soft proof kunde inte skapas</h1><p>ICC-profilen stöder inte denna färgkonvertering. Certifikatet är sparat.</p><a href="gradients-original.jpg">Originalgradienter (sRGB)</a></html>', encoding='utf-8')
        return metadata
    preview = ImageCms.applyTransform(original, transform)
    for filename, image in [('gradients-original.jpg', original), ('gradients-soft-proof.jpg', preview)]:
        image.save(destination / filename, quality=100, subsampling=0, icc_profile=srgb.tobytes())
    metadata = dict(documentType='inkprof.gradient-soft-proof',
                    profileSHA256=hashlib.sha256(profile.read_bytes()).hexdigest(),
                    available=True, sourceSpace='sRGB', displaySpace='sRGB', intent='relative colorimetric',
                    blackPointCompensation=True, physicalMeasurement=False)
    (destination / 'gradients.json').write_text(json.dumps(metadata, indent=2), encoding='utf-8')
    (destination / 'gradients.html').write_text('''<!doctype html><html lang="sv"><meta charset="utf-8">
<title>InkProf – gradienter</title><style>body{font:18px system-ui;margin:32px;max-width:1600px}img{width:100%;height:auto}button{font:inherit;padding:12px;margin-right:12px}code{overflow-wrap:anywhere}</style>
<h1>Gradienter med den levererade profilen</h1>
<p>sRGB · relativ kolorimetrisk · svartpunktskompensation. Rader: grå, röd, grön, blå, cyan, magenta, gul och blå himmel.</p>
<p>Skärmförhandsvisning av profilens förutsägelse. Ingen fysisk mätning. JPG är 8-bitars och kan själv ge steg i gradienter. Bedöm vid 100 % och med en kalibrerad skärm.</p>
<button onclick="show(false)">Original</button><button onclick="show(true)">Soft proof</button>
<button onclick="document.querySelector('img').style.width='1536px'">100 %</button><button onclick="document.querySelector('img').style.width='100%'">Anpassa</button>
<h2 id="label">Soft proof</h2><img src="gradients-soft-proof.jpg" alt="Åtta gradienter">
<p><a href="gradients-original.jpg">Original JPG</a> · <a href="gradients-soft-proof.jpg">Soft proof JPG</a> · <a href="gradients.json">Profil och inställningar</a></p>
<script>function show(proof){document.querySelector('img').src=proof?'gradients-soft-proof.jpg':'gradients-original.jpg';document.getElementById('label').textContent=proof?'Soft proof':'Original'}</script></html>''', encoding='utf-8')
    return metadata


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('profile')
    parser.add_argument('destination')
    args = parser.parse_args()
    create(args.profile, args.destination)
