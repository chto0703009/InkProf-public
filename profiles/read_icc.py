# Copyright (c) 2026 Christer Törnkvist.
# SPDX-License-Identifier: GPL-3.0-or-later
# InkProf is free software under GNU GPL version 3 or later.
# Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
"""Read-only ICC v2/v4 structural inspection. No LUT evaluation or rewriting."""
import argparse
import datetime
import hashlib
import json
from pathlib import Path
import struct


class ICCError(ValueError):
    pass


def inspect_bytes(data, source=''):
    def require(condition, message):
        if not condition:
            raise ICCError(message)
    def u32(buf, at):
        return struct.unpack_from('>I', buf, at)[0]
    def sig(buf, at):
        return buf[at:at+4].decode('latin1')
    require(len(data) >= 132, 'Truncated ICC header/tag directory.')
    require(data[36:40] == b'acsp', 'Missing ICC acsp signature.')
    size = u32(data, 0)
    require(132 <= size <= len(data), 'Declared ICC size is invalid or file is truncated.')
    major = data[8]
    require(major in (2, 4), f'Unsupported ICC major version: {major}. Expected v2 or v4.')
    count = u32(data, 128)
    require(count <= (size-132)//12, 'Tag directory exceeds declared profile size.')
    end_table = 132+12*count
    diagnostics = []
    def warn(code, message, offset=0, tag=''):
        diagnostics.append(dict(code=code, severity='warning', message=message, offset=offset, tag=tag))
    if size != len(data):
        warn('trailing_bytes', 'Bytes after the declared profile end are not interpreted.', size)
    date = struct.unpack_from('>6H', data, 24)
    try:
        created = datetime.datetime(*date).isoformat()
    except ValueError:
        created = None
        warn('invalid_date', 'Invalid header creation date.', 24)
    header = dict(declaredBytes=size, version=f'{major}.{data[9]>>4}.{data[9]&15}',
                  profileClass=sig(data, 12), deviceSpace=sig(data, 16), pcs=sig(data, 20),
                  cmm=sig(data, 4), creator=sig(data, 80), platform=sig(data, 40),
                  created=created, createdComponents=list(date), flags=u32(data, 44),
                  manufacturer=sig(data, 48), model=sig(data, 52),
                  attributesHex=data[56:64].hex(), renderingIntent=u32(data, 64),
                  pcsIlluminantXYZ=[x/65536 for x in struct.unpack_from('>3i', data, 68)],
                  profileID=data[84:100].hex() if major == 4 else None)
    if header['renderingIntent'] > 3:
        warn('invalid_intent', 'Unknown rendering intent.', 64)
    tags, seen, intervals, descriptions = [], set(), {}, []
    for i in range(count):
        at = 132+12*i
        signature = sig(data, at)
        offset, length = struct.unpack_from('>II', data, at+4)
        require(signature not in seen, f'Duplicate tag signature: {signature}.')
        seen.add(signature)
        require(offset % 4 == 0, f'Unaligned tag offset: {signature}.')
        require(offset >= end_table and length >= 8 and offset+length <= size,
                f'Tag outside profile bounds or too short: {signature}.')
        key = (offset, length)
        intervals.setdefault(key, []).append(signature)
        tags.append(dict(signature=signature, type=sig(data, offset), offset=offset,
                         size=length, sharedWith=[], summary='', decoded=None))
    previous_end = end_table
    for (offset, length), names in sorted(intervals.items()):
        require(offset >= previous_end, f'Partially overlapping tag data: {names[0]}.')
        previous_end = offset+length
    for tag in tags:
        off, length, kind = tag['offset'], tag['size'], tag['type']
        buf = data[off:off+length]
        tag['sharedWith'] = [n for n in intervals[(off, length)] if n != tag['signature']]
        try:
            if kind == 'mluc':
                require(len(buf) >= 16, 'Truncated mluc header.')
                n, stride = struct.unpack_from('>II', buf, 8)
                require(stride >= 12 and n <= (len(buf)-16)//stride, 'Invalid mluc record table.')
                texts = []
                for j in range(n):
                    pos = 16+j*stride
                    length_text, start = struct.unpack_from('>II', buf, pos+4)
                    require(length_text % 2 == 0 and start >= 16+n*stride and start+length_text <= len(buf), 'Invalid mluc text bounds.')
                    texts.append(dict(language=buf[pos:pos+2].decode('ascii'), country=buf[pos+2:pos+4].decode('ascii'), text=buf[start:start+length_text].decode('utf-16-be').rstrip('\0')))
                tag['decoded'] = texts
                tag['summary'] = ' | '.join(t['text'] for t in texts)
                if tag['signature'] == 'desc': descriptions.extend(texts)
            elif kind == 'desc':
                require(len(buf) >= 12, 'Truncated desc header.')
                n = u32(buf, 8)
                require(n >= 1 and 12+n <= len(buf), 'Invalid desc ASCII length.')
                text = buf[12:12+n].rstrip(b'\0').decode('ascii', errors='replace')
                pos = 12+n
                require(pos+8 <= len(buf), 'Truncated desc Unicode header.')
                language, chars = struct.unpack_from('>II', buf, pos)
                require(pos+8+2*chars <= len(buf), 'Invalid desc Unicode length.')
                unicode_text = buf[pos+8:pos+8+2*chars].decode('utf-16-be').rstrip('\0') if chars else ''
                tag['decoded'] = dict(ascii=text, unicode=unicode_text, languageCode=language)
                tag['summary'] = unicode_text or text
                if tag['signature'] == 'desc': descriptions.append(dict(language='', country='', text=tag['summary']))
            elif kind == 'text':
                tag['decoded'] = buf[8:].rstrip(b'\0').decode('ascii', errors='replace')
                tag['summary'] = tag['decoded'][:240]
            elif kind == 'XYZ ':
                require(len(buf) >= 20 and (len(buf)-8)%12 == 0, 'Invalid XYZ tag length.')
                tag['decoded'] = [[v/65536 for v in struct.unpack_from('>3i', buf, p)] for p in range(8, len(buf), 12)]
                tag['summary'] = str(tag['decoded'])
            else:
                tag['summary'] = 'Payload preserved in source; not decoded in A1.'
        except (ICCError, UnicodeError, struct.error) as exc:
            warn('tag_decode_failed', str(exc), off, tag['signature'])
            tag['summary'] = 'Could not decode; see diagnostics.'
    rgb_output = header['profileClass'] == 'prtr' and header['deviceSpace'] == 'RGB ' and header['pcs'] in ('Lab ', 'XYZ ')
    return dict(schemaVersion=1, documentType='inkprof.icc-inspection', readerVersion='1.0',
                inspectedUTC=datetime.datetime.now(datetime.timezone.utc).isoformat(),
                source=dict(path=str(source), sha256=hashlib.sha256(data).hexdigest(), bytes=len(data)),
                header=header, tags=tags, descriptions=descriptions, diagnostics=diagnostics,
                status='readable_with_warnings' if diagnostics else 'readable',
                capabilities=dict(rgbOutputCandidate=rgb_output, lutEvaluated=False, fullConformanceChecked=False, profileQualityValidated=False))


def inspect_file(path):
    path = Path(path).resolve()
    if path.stat().st_size > 256*1024*1024:
        raise ICCError('Profile exceeds the A1 safety limit of 256 MiB.')
    return inspect_bytes(path.read_bytes(), path)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('source')
    parser.add_argument('output')
    args = parser.parse_args()
    try:
        result = inspect_file(args.source)
        with Path(args.output).open('x', encoding='utf-8') as stream:
            json.dump(result, stream, ensure_ascii=False, indent=2, allow_nan=False)
    except (ICCError, OSError) as exc:
        parser.exit(2, f'ICC inspection failed: {exc}\n')


if __name__ == '__main__':
    main()
