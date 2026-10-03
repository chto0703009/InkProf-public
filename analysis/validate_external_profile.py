# Copyright (c) 2026 Christer Törnkvist.
# SPDX-License-Identifier: GPL-3.0-or-later
# InkProf is free software under GNU GPL version 3 or later.
# Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
"""Validate supported imported profiles without rebuilding them."""
import sys
from pathlib import Path
from profile_c1 import require_profile
if __name__=='__main__':
    require_profile(Path(sys.argv[1]).read_bytes())
    print('Supported RGB output ICC; structural checks passed. Print quality is not yet assessed.')
