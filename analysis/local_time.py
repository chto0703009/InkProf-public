# Copyright (c) 2026 Christer Törnkvist.
# SPDX-License-Identifier: GPL-3.0-or-later
# InkProf is free software under GNU GPL version 3 or later.
# Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
"""Local display of recorded instants; UTC source evidence is unchanged."""
from datetime import datetime


def local_time(value):
    instant = datetime.fromisoformat(value.replace('Z', '+00:00'))
    if instant.tzinfo is None:
        raise ValueError('Timestamp must include its source time zone.')
    local = instant.astimezone()
    return local.isoformat(sep=' ', timespec='seconds') + ' (' + local.tzname() + ')'


def report_time(record):
    """Prefer a recorded local display; retain date-only legacy reports as dates."""
    if record.get('createdLocal'):
        return record['createdLocal']
    value = record.get('createdUTC')
    if not value:
        return record.get('reportDate', '')
    if len(value) == 10:
        return value  # A date alone does not identify an instant.
    instant = datetime.fromisoformat(value.replace('Z', '+00:00'))
    if instant.tzinfo is None:
        # This legacy field explicitly states UTC, despite missing its suffix.
        from datetime import timezone
        instant = instant.replace(tzinfo=timezone.utc)
    return local_time(instant.isoformat())
