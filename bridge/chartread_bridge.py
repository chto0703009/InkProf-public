# Copyright (c) 2026 Christer Törnkvist.
# SPDX-License-Identifier: GPL-3.0-or-later
# InkProf is free software under GNU GPL version 3 or later.
# Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
"""POSIX PTY transport for chartread. JSON-lines stdin/stdout; raw transcript on disk.
No prompt guessing, automatic keypresses, or claims of successful measurement.
"""
import argparse
import math
import codecs
import hashlib
import json
import os
import re
from pathlib import Path
import selectors
import signal
import subprocess
import sys
import time


def emit(kind, **data):
    print(json.dumps(dict(event=kind, **data)), flush=True)


def sequence(value):
    return value if isinstance(value, list) else [value]


def quote(value):
    text = str(value)
    if any(c in text for c in ('"', '\n', '\r')):
        raise ValueError('Unsupported quoted token in chart JSON')
    return '"' + text + '"'


def chart_to_ti2(chart):
    if chart.get('schemaVersion') != 1 or chart.get('documentType') != 'inkprof.measurement-chart' or chart.get('colorSpace') != 'RGB':
        raise ValueError('Expected RGB chart JSON schema 1')
    import math
    patches = sequence(chart['patches'])
    if len(patches) != chart['patchCount']:
        raise ValueError('Patch count mismatch')
    locations = [p['sampleLoc'] for p in patches]
    ids = [p['sampleId'] for p in patches if p['sampleId'] != '0']
    if len(set(locations)) != len(locations) or len(set(ids)) != len(ids):
        raise ValueError('Duplicate patch identities')
    for patch in patches:
        rgb = patch['rgbPercent']
        if len(rgb) != 3 or not all(math.isfinite(v) and 0 <= v <= 100 for v in rgb):
            raise ValueError('Invalid RGB channels')
    lines = []
    for index, table in enumerate(sequence(chart['exchangeTables'])):
        fields = sequence(table['fields'])
        rows = [sequence(r['values']) for r in sequence(table['rows'])]
        if index == 0:
            if table['signature'] != 'CTI2' or len(rows) != len(patches):
                raise ValueError('Invalid CTI2 template')
            positions = [fields.index(k) for k in ['SAMPLE_ID', 'SAMPLE_LOC', 'RGB_R', 'RGB_G', 'RGB_B']]
            for row, patch in zip(rows, patches):
                values = [patch['sampleId'], patch['sampleLoc']] + [format(v, '.17g') for v in patch['rgbPercent']]
                for col, value in zip(positions, values):
                    row[col] = value
        lines.append(table['signature'])
        for meta in sequence(table['metadata']):
            tokens = sequence(meta['tokens'])
            if tokens[0] not in ['NUMBER_OF_FIELDS', 'NUMBER_OF_SETS']:
                lines.append(tokens[0] + ' ' + ' '.join(quote(v) for v in tokens[1:]))
        lines += [f'NUMBER_OF_FIELDS {len(fields)}', 'BEGIN_DATA_FORMAT', ' '.join(fields),
                  'END_DATA_FORMAT', f'NUMBER_OF_SETS {len(rows)}', 'BEGIN_DATA']
        for row in rows:
            if len(row) != len(fields):
                raise ValueError('Invalid row width')
            lines.append(' '.join(
                str(v) if field not in ('SAMPLE_ID', 'SAMPLE_NAME', 'SAMPLE_LOC')
                and re.fullmatch(r'[+-]?(?:\d+(?:\.\d*)?|\.\d+)(?:[eE][+-]?\d+)?', str(v))
                else quote(v) for field, v in zip(fields, row)))
        lines += ['END_DATA', '']
    return '\n'.join(lines)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('session')
    parser.add_argument('executable')
    parser.add_argument('--resume', action='store_true')
    parser.add_argument('--port', type=int)
    parser.add_argument('--scan-tolerance', type=float, default=1.0)
    parser.add_argument('--direction', choices=['auto', 'forward', 'both'], default='auto')
    opt = parser.parse_args()
    if not math.isfinite(opt.scan_tolerance) or opt.scan_tolerance <= 0:
        parser.error('Scan tolerance must be finite and positive')
    if os.name != 'posix':
        raise RuntimeError('Interactive chartread currently requires macOS/Linux PTY support.')
    import fcntl
    import pty
    folder = Path(opt.session).resolve()
    with (folder / 'chartread.lock').open('a') as lock:
        fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        chart_bytes = (folder / 'chart.json').read_bytes()
        chart = json.loads(chart_bytes)
        chart_hash = hashlib.sha256(chart_bytes).hexdigest()
        input_record = folder / 'chartread-input.json'
        if opt.resume and (not input_record.exists() or json.loads(input_record.read_text())['chartJSONSHA256'] != chart_hash):
            raise RuntimeError('Resume requires the same JSON chart as the previous run')
        result = folder / 'chart.ti3'
        if result.exists() and not opt.resume:
            raise RuntimeError('TI3 exists; use resume explicitly or prepare a new session.')
        if opt.resume and not result.exists():
            raise RuntimeError('Resume requires a saved chart.ti3.')
        ti2 = chart_to_ti2(chart).encode('utf-8')
        actual = hashlib.sha256(ti2).hexdigest()
        (folder / 'chart.ti2').write_bytes(ti2)
        input_record.write_text(json.dumps(dict(chartJSONSHA256=chart_hash, ti2SHA256=actual), indent=2))
        token = str(time.time_ns())
        if result.exists():
            (folder / f'before-resume-{token}.ti3').write_bytes(result.read_bytes())
        args = [str(Path(opt.executable).resolve()), '-v', '-T', format(opt.scan_tolerance, '.17g')]
        if opt.direction == 'forward':
            args.append('-B')
        elif opt.direction == 'both':
            args.append('-b')
        if opt.resume:
            args.append('-r')
        if opt.port is not None:
            if opt.port < 1:
                raise RuntimeError('Port must be positive')
            args.extend(['-c', str(opt.port)])
        args.append('chart')  # spectral information is enabled by default; never pass -n
        version = subprocess.run([args[0], '-?'], capture_output=True, text=True, timeout=15)
        metadata = dict(arguments=args, started=time.time(), version=version.stdout+version.stderr,
                        resume=opt.resume, ti2SHA256=actual, physicalMeasurementVerified=False)
        (folder / f'run-{token}.json').write_text(json.dumps(metadata, indent=2))
        for attempt in range(1, 4):
            attempt_token = token if attempt == 1 else f'{token}-attempt-{attempt}'
            metadata.update(attempt=attempt, started=time.time())
            for key in ('exitCode', 'ended', 'ti3Exists'):
                metadata.pop(key, None)
            (folder / f'run-{attempt_token}.json').write_text(json.dumps(metadata, indent=2))
            output = ''
            sent_key = False
            master, slave = pty.openpty()
            proc = None
            sel = None
            decoder = codecs.getincrementaldecoder('utf-8')('replace')
            try:
                proc = subprocess.Popen(args, cwd=folder, stdin=slave, stdout=slave, stderr=slave,
                                        start_new_session=True, close_fds=True)
                os.close(slave)
                slave = None
                emit('started', pid=proc.pid, arguments=args)
                sel = selectors.DefaultSelector()
                sel.register(master, selectors.EVENT_READ, 'output')
                sel.register(sys.stdin, selectors.EVENT_READ, 'input')
                pending = b''
                with (folder / f'transcript-{attempt_token}.txt').open('wb') as log:
                    active = True
                    while active:
                        for key, _ in sel.select(timeout=.1):
                            if key.data == 'output':
                                try:
                                    data = os.read(master, 65536)
                                except OSError:
                                    data = b''
                                if not data:
                                    active = False
                                    break
                                log.write(data)
                                log.flush()
                                text = decoder.decode(data)
                                output += text
                                emit('output', text=text)
                            else:
                                data = os.read(sys.stdin.fileno(), 65536)
                                if not data:
                                    raise RuntimeError('Controller disconnected; stopping child')
                                pending += data
                                while b'\n' in pending:
                                    line, pending = pending.split(b'\n', 1)
                                    msg = json.loads(line)
                                    if msg.get('command') == 'stop':
                                        raise RuntimeError('Stopped by controller; unsaved readings may be lost')
                                    if msg.get('command') != 'key' or not isinstance(msg.get('text'), str) or len(msg['text']) != 1:
                                        emit('error', message='Expected one key character')
                                        continue
                                    sent_key = True
                                    os.write(master, msg['text'].encode('utf-8'))
                    tail = decoder.decode(b'', final=True)
                    if tail:
                        emit('output', text=tail)
                code = proc.wait(timeout=5)
                metadata.update(exitCode=code, ended=time.time(), ti3Exists=result.exists())
                (folder / f'run-{attempt_token}.json').write_text(json.dumps(metadata, indent=2))
                # Retry only the observed startup communications failure, never a
                # calibration/scan error, a user interaction or an existing result.
                retry = (code != 0 and attempt < 3 and not sent_key and not result.exists()
                         and 'Initialising instrument failed' in output
                         and 'Communications failure' in output
                         and 'Place the instrument' not in output
                         and 'Ready to read' not in output)
                if retry:
                    emit('output', text=f'\nInstrument connection failed before calibration. Reconnecting ({attempt + 1}/3); please wait.\n')
                    time.sleep(2)
                    continue
                emit('exited', exitCode=code, ti3Exists=result.exists(), validated=False)
                return 0 if code == 0 else 1
            finally:
                if proc is not None and proc.poll() is None:
                    os.killpg(proc.pid, signal.SIGTERM)
                    try:
                        proc.wait(timeout=3)
                    except subprocess.TimeoutExpired:
                        os.killpg(proc.pid, signal.SIGKILL)
                        proc.wait()
                if sel is not None:
                    sel.close()
                os.close(master)
                if slave is not None:
                    os.close(slave)



if __name__ == '__main__':
    try:
        sys.exit(main())
    except Exception as error:
        emit('error', message=str(error))
        sys.exit(1)
