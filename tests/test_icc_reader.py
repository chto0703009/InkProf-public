# Copyright (c) 2026 Christer Törnkvist.
# SPDX-License-Identifier: GPL-3.0-or-later
# InkProf is free software under GNU GPL version 3 or later.
# Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
import importlib.util
from pathlib import Path
import struct
import unittest

spec=importlib.util.spec_from_file_location('icc_reader',Path(__file__).resolve().parents[1]/'profiles/read_icc.py')
m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)

def fixture(entries=None):
    if entries is None: entries=[(b'cprt',b'text'+bytes(4)+b'test\0')]
    b=bytearray(132+12*len(entries));b[8:10]=bytes([4,0x20]);b[12:24]=b'prtrRGB Lab ';b[36:40]=b'acsp'
    struct.pack_into('>6H',b,24,2026,9,27,12,0,0);struct.pack_into('>I',b,128,len(entries))
    for i,(name,payload) in enumerate(entries):
        while len(b)%4:b.append(0)
        offset=len(b);b.extend(payload)
        struct.pack_into('>4sII',b,132+12*i,name,offset,len(payload))
    while len(b)%4:b.append(0)
    struct.pack_into('>I',b,0,len(b));return b

class ReaderTests(unittest.TestCase):
    def test_basic(self):
        r=m.inspect_bytes(fixture());self.assertEqual(r['status'],'readable');self.assertTrue(r['capabilities']['rgbOutputCandidate'])
    def test_truncated(self):
        with self.assertRaises(m.ICCError):m.inspect_bytes(fixture()[:-1])
    def test_bad_signature(self):
        b=fixture();b[36]=0
        with self.assertRaises(m.ICCError):m.inspect_bytes(b)
    def test_directory_bounds(self):
        b=fixture();struct.pack_into('>I',b,128,9999999)
        with self.assertRaises(m.ICCError):m.inspect_bytes(b)
    def test_shared_and_overlap(self):
        b=fixture([(b'cprt',b'text'+bytes(4)+b'abcdefghijk'),(b'desc',b'text'+bytes(4)+b'xyz')])
        b[148:156]=b[136:144]
        self.assertEqual(m.inspect_bytes(b)['tags'][0]['sharedWith'],['desc'])
        off=struct.unpack_from('>I',b,148)[0];struct.pack_into('>II',b,148,off+4,8)
        with self.assertRaises(m.ICCError):m.inspect_bytes(b)
    def test_duplicate(self):
        b=fixture([(b'cprt',b'text'+bytes(4)),(b'cprt',b'text'+bytes(4))])
        with self.assertRaises(m.ICCError):m.inspect_bytes(b)
    def test_unicode_and_bad_bounds(self):
        text='Grå – blå'.encode('utf-16-be')
        payload=b'mluc'+bytes(4)+struct.pack('>II',1,12)+b'svSE'+struct.pack('>II',len(text),28)+text
        r=m.inspect_bytes(fixture([(b'desc',payload)]));self.assertEqual(r['descriptions'][0]['text'],'Grå – blå')
        payload=payload[:24]+struct.pack('>I',999999)+text
        self.assertEqual(m.inspect_bytes(fixture([(b'desc',payload)]))['diagnostics'][0]['code'],'tag_decode_failed')
    def test_other_colour_space(self):
        b=fixture();b[16:20]=b'CMYK';self.assertFalse(m.inspect_bytes(b)['capabilities']['rgbOutputCandidate'])
    def test_unsupported_version(self):
        b=fixture();b[8]=5
        with self.assertRaises(m.ICCError):m.inspect_bytes(b)

if __name__=='__main__':unittest.main()
