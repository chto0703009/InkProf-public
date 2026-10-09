# Copyright (c) 2026 Christer Törnkvist.
# SPDX-License-Identifier: GPL-3.0-or-later
# InkProf is free software under GNU GPL version 3 or later.
# Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
"""Version-aware colour lookups for verification; v4 never enters xicclu."""
from pathlib import Path
from profile_grid import lookup as argyll_lookup
from lcms_float import LittleCMS

def is_v4(profile):
    with Path(profile).open('rb') as f:
        header=f.read(128)
    if len(header)!=128:raise ValueError('Incomplete ICC header.')
    return header[8]==4

def lookup(exe,profile,values,direction='f',intent='r'):
    if not is_v4(profile):return argyll_lookup(exe,profile,values,direction,intent)
    if intent not in ('r','a') or direction not in ('f','b','if'):
        raise ValueError('Unsupported v4 lookup.')
    return LittleCMS().transform(profile,values,'b' if direction in ('b','if') else 'f',1 if intent=='r' else 3)

def evidence(profile):
    if is_v4(profile):
        c=LittleCMS()
        return dict(engine='LittleCMS',version=c.version,inverse='Stored B2A; residual is not numerical A2B inversion')
    return dict(engine='Argyll xicclu',inverse='Stored B2A for target; numerical A2B inversion for reachability')
