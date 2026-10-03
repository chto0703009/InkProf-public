# Copyright (c) 2026 Christer Törnkvist.
# SPDX-License-Identifier: GPL-3.0-or-later
# InkProf is free software under GNU GPL version 3 or later.
# Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
"""Read readiness is advisory: temporary unavailability is not EOF."""
import errno
import os


def read_ready(fd, *, pty_output=False):
    """Return bytes, None to wait again, or empty bytes for EOF only."""
    try:
        return os.read(fd, 65536)
    except OSError as error:
        if error.errno in (errno.EAGAIN, errno.EWOULDBLOCK, errno.EINTR):
            return None
        # POSIX PTYs can report EIO when the slave closes. Pipes cannot.
        if pty_output and error.errno == errno.EIO:
            return b''
        raise
