# Copyright (c) 2026 Christer Törnkvist.
# SPDX-License-Identifier: GPL-3.0-or-later
# InkProf is free software under GNU GPL version 3 or later.
# Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
"""Exercise transient transport errors without accessing an instrument."""
import errno
from pathlib import Path
import sys
import unittest
from unittest.mock import patch
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'bridge'))
from pty_transport import read_ready


class TransportTests(unittest.TestCase):
    def test_temporary_error_preserves_next_read(self):
        for output in (False, True):
            for code in (errno.EAGAIN, errno.EWOULDBLOCK, errno.EINTR):
                with self.subTest(output=output, code=code), patch(
                        'pty_transport.os.read', side_effect=[OSError(code, 'temporary'), b'prompt']):
                    self.assertIsNone(read_ready(123, pty_output=output))
                    self.assertEqual(read_ready(123, pty_output=output), b'prompt')

    def test_only_pty_eio_is_eof(self):
        with patch('pty_transport.os.read', side_effect=OSError(errno.EIO, 'closed')):
            self.assertEqual(read_ready(123, pty_output=True), b'')
            with self.assertRaises(OSError):
                read_ready(123)

    def test_unexpected_errors_are_not_hidden(self):
        with patch('pty_transport.os.read', side_effect=OSError(errno.EBADF, 'invalid')):
            with self.assertRaises(OSError):
                read_ready(123, pty_output=True)

    def test_real_eof(self):
        with patch('pty_transport.os.read', return_value=b''):
            self.assertEqual(read_ready(123), b'')
