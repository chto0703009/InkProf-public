# Copyright (c) 2026 Christer Törnkvist.
# SPDX-License-Identifier: GPL-3.0-or-later
# Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
"""Report actual Argyll v2 LUT dimensions, not quality-derived estimates."""
import json
import struct
from pathlib import Path
from read_icc import inspect_bytes


def grids(path):
    data = Path(path).read_bytes()
    metadata = inspect_bytes(data)
    rows = []
    for tag in metadata['tags']:
        if not tag['signature'].startswith(('A2B', 'B2A')):
            continue
        off, size = tag['offset'], tag['size']
        if tag['type'] not in ('mft1', 'mft2') or size < (52 if tag['type'] == 'mft2' else 48):
            raise ValueError('Grid trial requires valid mft1/mft2 colour tables.')
        channels, outputs, n = data[off+8:off+11]
        if channels != 3 or outputs != 3 or n < 2:
            raise ValueError('Grid trial requires RGB/Lab three-channel LUTs.')
        if tag['type'] == 'mft2':
            ni, no = struct.unpack_from('>HH', data, off+48)
            expected = 52+2*(channels*ni+n**channels*outputs+outputs*no)
        else:
            expected = 48+256*channels+n**channels*outputs+256*outputs
        if size < expected:
            raise ValueError('Truncated colour LUT.')
        rows.append(dict(table=tag['signature'], levels=n, points=n**channels))
    if not rows:
        raise ValueError('No colour LUTs found.')
    return dict(profileSHA256=metadata['source']['sha256'], tables=rows)


def compare(source, candidate):
    before, after = grids(source), grids(candidate)
    old = {row['table']: row for row in before['tables']}
    rows = [dict(table=row['table'], sourceLevels=old[row['table']]['levels'],
                 sourcePoints=old[row['table']]['points'], candidateLevels=row['levels'],
                 candidatePoints=row['points'], increased=row['levels']>old[row['table']]['levels'])
            for row in after['tables'] if row['table'] in old]
    return dict(source=before, candidate=after, comparison=rows,
                caveat='Numerical trial from the same measurements. A denser ICC table does not establish improved print accuracy.')


if __name__ == '__main__':
    import sys
    Path(sys.argv[3]).write_text(json.dumps(compare(sys.argv[1],sys.argv[2]),indent=2,allow_nan=False))
