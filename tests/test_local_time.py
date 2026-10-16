# Copyright (c) 2026 Christer Törnkvist.
# SPDX-License-Identifier: GPL-3.0-or-later
# InkProf is free software under GNU GPL version 3 or later.
# Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
import os
import sys
import time
import unittest
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'analysis'))
from local_time import local_time, report_time


@unittest.skipUnless(hasattr(time, 'tzset'), 'Requires local time-zone selection')
class LocalTimeTests(unittest.TestCase):
    def test_dst_and_midnight(self):
        old = os.environ.get('TZ')
        try:
            os.environ['TZ'] = 'Europe/Stockholm'
            time.tzset()
            self.assertIn('13:00:00+01:00', local_time('2026-01-15T12:00:00Z'))
            self.assertIn('14:00:00+02:00', local_time('2026-07-15T12:00:00+00:00'))
            self.assertIn('2026-07-16 01:30:00+02:00', local_time('2026-07-15T23:30:00.123456Z'))
            self.assertEqual(report_time({'createdUTC': '2026-07-15'}), '2026-07-15')
            self.assertEqual(report_time({'reportDate': '2026-07-15'}), '2026-07-15')
            self.assertIn('14:00:00+02:00', report_time({'createdUTC': '2026-07-15T12:00:00'}))
            with self.assertRaises(ValueError):
                local_time('2026-07-15T12:00:00')
        finally:
            if old is None:
                os.environ.pop('TZ', None)
            else:
                os.environ['TZ'] = old
            time.tzset()
