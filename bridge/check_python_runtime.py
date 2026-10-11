# Copyright (c) 2026 Christer Törnkvist.
# SPDX-License-Identifier: GPL-3.0-or-later
# InkProf is free software under GNU GPL version 3 or later.
# Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
"""Check actual imports, including SciPy's compiled spatial/PROPACK chain."""
import importlib
import json
import platform
import sys
from pathlib import Path


def check_modules(modules):
    missing, failures = [], []
    for module in modules:
        try:
            importlib.import_module(module)
            if module == "scipy":
                spatial = importlib.import_module("scipy.spatial")
                linalg = importlib.import_module("scipy.sparse.linalg")
                spatial.cKDTree([[0.0, 0.0]]).query([[0.0, 0.0]])
                getattr(linalg, "svds")
        except ModuleNotFoundError as error:
            if error.name == module:
                missing.append(module)
            else:
                failures.append({"module": module, "message": str(error)})
        except Exception as error:
            failures.append({"module": module,
                             "message": f"{type(error).__name__}: {error}"})
    return {"version": list(sys.version_info[:3]), "executable": sys.executable,
            "prefix": sys.prefix, "basePrefix": sys.base_prefix,
            "architecture": platform.machine(), "missing": missing,
            "failures": failures}


if __name__ == "__main__":
    Path(sys.argv[1]).write_text(json.dumps(check_modules(sys.argv[2:])),
                               encoding="utf-8")
