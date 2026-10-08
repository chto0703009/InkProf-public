# Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
# Copyright (c) 2026 Christer Törnkvist.
# SPDX-License-Identifier: GPL-3.0-or-later
"""Resolve only the checksum-verified ICC attached to this measurement target."""
from pathlib import Path
import json
import gamut_surface


def chart_gamut(chart,ti2,folder,executable):
    if not executable:return None,'Argyll iccgamut is unavailable.'
    ti2=Path(ti2).resolve();root=ti2.parent.parent;reference=root/'verification.json'
    if not reference.exists():return None,'No ICC-linked verification target; measured points do not define an ICC gamut.'
    ref=json.loads(reference.read_text())
    if not ti2.exists() or gamut_surface.digest(ti2)!=chart.get('sourceSHA256') or ref.get('printPackage',{}).get('ti2SHA256')!=chart.get('sourceSHA256'):
        raise ValueError('Measurement chart and ICC-linked target identity mismatch.')
    profile=(root/ref['printerProfile']['file']).resolve()
    if not profile.is_relative_to(root) or gamut_surface.digest(profile)!=ref['printerProfile']['sha256']:
        raise ValueError('Measurement target ICC integrity mismatch.')
    try:
        meta=gamut_surface.generate(profile,folder,executable)
        return gamut_surface.load(folder,dict(gamut=meta,profile=dict(sha256=meta['profileSHA256']))),''
    except (RuntimeError,OSError,ValueError) as error:
        return None,str(error)
