# Copyright (c) 2026 Christer Törnkvist.
# SPDX-License-Identifier: GPL-3.0-or-later
# InkProf is free software under GNU GPL version 3 or later.
# Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
"""LittleCMS public C API with double RGB/Lab buffers (not Pillow's 8-bit path).
API constants/signatures: LittleCMS lcms2.h, MIT, see THIRD_PARTY_NOTICES.md.
No claim that internal LUT calculations use double precision throughout.
"""
import ctypes as C
import ctypes.util
import os
from pathlib import Path
import numpy as np

RGB_DBL = (1 << 22) | (4 << 16) | (3 << 3)
LAB_DBL = (1 << 22) | (10 << 16) | (3 << 3)

class LittleCMS:
    def __init__(self, library=None):
        candidates = [library or os.environ.get('INKPROF_LCMS2_LIBRARY')]
        if not candidates[0]:
            from PIL import _imagingcms
            candidates = [_imagingcms.__file__, ctypes.util.find_library('lcms2')]
        errors=[]
        loader=C.WinDLL if os.name=='nt' else C.CDLL
        for path in candidates:
            if not path: continue
            try:
                lib=loader(str(path))
                definitions={
                    'cmsGetEncodedCMMversion':([],C.c_uint32),
                    'cmsOpenProfileFromMem':([C.c_void_p,C.c_uint32],C.c_void_p),
                    'cmsCreateLab4Profile':([C.c_void_p],C.c_void_p),
                    'cmsSaveProfileToFile':([C.c_void_p,C.c_char_p],C.c_int),
                    'cmsCreateTransform':([C.c_void_p,C.c_uint32,C.c_void_p,C.c_uint32,C.c_uint32,C.c_uint32],C.c_void_p),
                    'cmsDoTransform':([C.c_void_p,C.c_void_p,C.c_void_p,C.c_uint32],None),
                    'cmsDeleteTransform':([C.c_void_p],None),
                    'cmsCloseProfile':([C.c_void_p],C.c_int),
                }
                for name,(args,result) in definitions.items():
                    fn=getattr(lib,name);fn.argtypes=args;fn.restype=result
                self.lib=lib;self.path=str(path);self.version=int(lib.cmsGetEncodedCMMversion());return
            except (OSError,AttributeError) as exc: errors.append(str(exc))
        raise RuntimeError('LittleCMS C API unavailable. Set INKPROF_LCMS2_LIBRARY to a matching library. '+ '; '.join(errors))

    def save_lab_profile(self, path):
        handle=self.lib.cmsCreateLab4Profile(None)
        if not handle: raise ValueError('Cannot create Lab profile.')
        try:
            if not self.lib.cmsSaveProfileToFile(handle,os.fsencode(path)):
                raise ValueError('Cannot save Lab source profile.')
        finally: self.lib.cmsCloseProfile(handle)

    def transform(self, profile, values, direction='f'):
        if direction not in ('f','b','lab-identity'): raise ValueError('Unsupported direction.')
        values=np.ascontiguousarray(values,dtype=np.float64)
        if values.ndim!=2 or values.shape[1]!=3 or not np.isfinite(values).all(): raise ValueError('Expected finite N x 3 values.')
        out=np.empty_like(values);lib=self.lib;handles=[];transform=None
        try:
            lab=lib.cmsCreateLab4Profile(None)
            if not lab: raise ValueError('Cannot create Lab profile.')
            handles.append(lab)
            if direction=='lab-identity': src=dst=lab;itype=otype=LAB_DBL
            else:
                data=Path(profile).read_bytes();buffer=C.create_string_buffer(data)
                icc=lib.cmsOpenProfileFromMem(buffer,len(data))
                if not icc: raise ValueError('LittleCMS rejected profile.')
                handles.append(icc)
                src,dst,itype,otype=(icc,lab,RGB_DBL,LAB_DBL) if direction=='f' else (lab,icc,LAB_DBL,RGB_DBL)
            # Relative colorimetric, no BPC; disable cache/optimization for diagnostic evaluation.
            transform=lib.cmsCreateTransform(src,itype,dst,otype,1,0x0100|0x0040)
            if not transform: raise ValueError('LittleCMS could not build transform.')
            lib.cmsDoTransform(transform,values.ctypes.data,out.ctypes.data,len(values))
            if not np.isfinite(out).all(): raise ValueError('Nonfinite LittleCMS output.')
            return out
        finally:
            if transform: lib.cmsDeleteTransform(transform)
            for handle in reversed(handles): lib.cmsCloseProfile(handle)
