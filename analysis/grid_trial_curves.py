# Copyright (c) 2026 Christer Törnkvist.
# SPDX-License-Identifier: GPL-3.0-or-later
# Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
"""Matching diagnostic paths through source and trial ICCs."""
import json
import sys
from pathlib import Path
import numpy as np
from rgb_gradients import ramps
from lcms_float import LittleCMS
from gamut_surface import digest


def run(source, candidate, output):
    hashes=[digest(source),digest(candidate)]
    cmm=LittleCMS(); paths=[]
    for name, rgb in ramps(257).items():
        values=[]
        for profile in (source,candidate):
            device=cmm.photo_transform(profile,rgb,'sRGB',1,False,None)
            lab=cmm.transform(profile,device,'f')
            values.append(dict(rgbPercent=(device*100).tolist(),lab=lab.tolist()))
        paths.append(dict(name=name,source=values[0],candidate=values[1]))
    if hashes!=[digest(source),digest(candidate)]:raise ValueError('ICC changed during curve comparison.')
    result=dict(sourceSHA256=hashes[0],candidateSHA256=hashes[1],paths=paths,
                method='Matched sRGB paths; relative colorimetric, BPC off, float LittleCMS. Predicted values, not print measurements.')
    Path(output).write_text(json.dumps(result,allow_nan=False))

if __name__=='__main__':run(*sys.argv[1:])
