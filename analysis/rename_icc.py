# Copyright (c) 2026 Christer Törnkvist.
# SPDX-License-Identifier: GPL-3.0-or-later
# InkProf is free software under GNU GPL version 3 or later.
# Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
"""Change the ICC display name while preserving every other tag payload.
ICC profile ID: ICC.1 bytes 44..47, 64..67 and 84..99 are zero for MD5.
"""
import hashlib
import json
import struct
import sys
from pathlib import Path


def tags(data):
    if len(data) < 132 or data[36:40] != b'acsp' or struct.unpack_from('>I', data)[0] != len(data):
        raise ValueError('Invalid ICC size or signature')
    count = struct.unpack_from('>I', data, 128)[0]
    if 132 + 12 * count > len(data):
        raise ValueError('Invalid ICC tag table')
    result = {}
    for i in range(count):
        key, start, length = struct.unpack_from('>4sII', data, 132 + 12*i)
        if key in result or start < 132 + 12*count or start+length > len(data):
            raise ValueError('Invalid ICC tag range or duplicate signature')
        result[key] = data[start:start+length]
    return result


def rename(source, destination, name):
    original = Path(source).read_bytes()
    before = tags(original)
    if not name.strip() or '\0' in name:
        raise ValueError('A nonempty profile name without NUL is required')
    if original[8] >= 4:
        encoded = name.encode('utf-16-be')
        description = b'mluc'+bytes(4)+struct.pack('>II2s2sII', 1, 12, b'en', b'US', len(encoded), 28)+encoded
    else:
        ascii_name = name.encode('ascii') + b'\0'
        description = b'desc'+bytes(4)+struct.pack('>I',len(ascii_name))+ascii_name+bytes(8+2+1+67)
    updated = dict(before);updated[b'desc'] = description
    result = bytearray(original[:128]) + struct.pack('>I',len(updated)) + bytes(12*len(updated))
    stored = {}
    for i, (key,payload) in enumerate(updated.items()):
        if payload not in stored:
            result += bytes((-len(result)) % 4)
            stored[payload] = len(result);result += payload
        struct.pack_into('>4sII',result,132+12*i,key,stored[payload],len(payload))
    result += bytes((-len(result)) % 4)
    struct.pack_into('>I',result,0,len(result))
    result[84:100] = bytes(16)
    if original[8] >= 4:
        for_hash=bytearray(result);for_hash[44:48]=bytes(4);for_hash[64:68]=bytes(4)
        result[84:100]=hashlib.md5(for_hash).digest()
    after=tags(result)
    assert {k:v for k,v in before.items() if k!=b'desc'} == {k:v for k,v in after.items() if k!=b'desc'}
    Path(destination).write_bytes(result)
    return dict(internalName=name,sourceSHA256=hashlib.sha256(original).hexdigest(),sha256=hashlib.sha256(result).hexdigest(),
                byteIdentical=False,colourTagPayloadsUnchanged=True,changedTag='desc',profileID=result[84:100].hex())


if __name__=='__main__':
    receipt=rename(sys.argv[1],sys.argv[2],sys.argv[3])
    Path(sys.argv[4]).write_text(json.dumps(receipt,indent=2,ensure_ascii=False),encoding='utf-8')
