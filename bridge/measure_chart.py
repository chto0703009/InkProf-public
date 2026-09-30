"""Own the measurement session; chartread inherits the real terminal directly.
No prompt parsing, automatic acknowledgements, or MATLAB keyboard forwarding.
"""
import argparse
import hashlib
import json
import math
import os
from pathlib import Path
import shlex
import signal
import subprocess
import sys
import time
import uuid

from chartread_bridge import chart_to_ti2


def digest(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def save(path, data):
    path = Path(path)
    tmp = path.with_name(path.name + '.tmp')
    tmp.write_text(json.dumps(data, indent=2), encoding='utf-8')
    tmp.replace(path)


def check(folder, resume, expected=None):
    chart = folder / 'chart.json'
    chart_hash = digest(chart)
    if expected is not None and chart_hash != expected:
        raise ValueError('Chart JSON changed since launch preparation')
    data = json.loads(chart.read_text())
    ti2 = chart_to_ti2(data)
    result = folder / 'chart.ti3'
    if resume:
        record = folder / 'chartread-input.json'
        if not result.is_file() or not record.is_file():
            raise ValueError('Resume requires a saved chart.ti3 and its input record')
        if json.loads(record.read_text())['chartJSONSHA256'] != chart_hash:
            raise ValueError('Resume requires the same chart JSON as the saved measurement')
    elif result.exists():
        raise ValueError('TI3 exists; use Resume=true or a new session')
    return chart_hash, ti2


def prepare(folder, executable, resume=False, port=0, scan_tolerance=1.0, direction="auto"):
    if not math.isfinite(scan_tolerance) or scan_tolerance <= 0:
        raise ValueError("Scan tolerance must be finite and positive")
    if direction not in ("auto", "forward", "both"):
        raise ValueError("Invalid reading direction")
    folder = Path(folder).resolve()
    executable = Path(executable).resolve()
    if not executable.is_file():
        raise ValueError('chartread executable is missing')
    chart_hash, _ = check(folder, resume)
    token = uuid.uuid4().hex
    record = folder / ('terminal-run-' + token + '.json')
    launcher = folder / ('measure-' + token + '.command')
    data = dict(schemaVersion=1, documentType='inkprof.terminal-measurement',
                status='ready', folder=str(folder), executable=str(executable),
                resume=resume, port=port, scanTolerance=scan_tolerance, direction=direction, chartJSONSHA256=chart_hash,
                prepared=time.time(), launcher=str(launcher), runId=token)
    save(record, data)
    # shlex quotes spaces, apostrophes and shell metacharacters; no shell evaluation
    # of a project path. Python keeps the terminal until the user closes it.
    argv = [sys.executable, str(Path(__file__).resolve()), 'run', str(record)]
    launcher.write_text('#!/bin/sh\nexec ' + shlex.join(argv) + '\n', encoding='utf-8')
    launcher.chmod(0o700)
    return dict(record=str(record), launcher=str(launcher), folder=str(folder))


def run(record):
    import fcntl
    record = Path(record).resolve()
    data = json.loads(record.read_text())
    folder = Path(data['folder'])
    # Lock matches the legacy bridge, so both entry points cannot own one session.
    with (folder / 'chartread.lock').open('a') as lock:
        fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        if data['status'] != 'ready':
            raise ValueError('This launch has already been used; prepare a new run')
        child = None
        old_handlers = {}
        def interrupted(signum, frame):
            raise InterruptedError('Terminal closed or interrupted (signal %d)' % signum)
        try:
            if not sys.stdin.isatty() or not sys.stdout.isatty():
                raise ValueError('Open the .command file in Terminal; an interactive terminal is required')
            chart_hash, ti2 = check(folder, data['resume'], data['chartJSONSHA256'])
            original = folder / 'chart.ti3'
            if original.exists():
                backup = folder / ('before-' + data['runId'] + '.ti3')
                with backup.open('xb') as f:
                    f.write(original.read_bytes())
                data['previousTI3'] = str(backup)
                data['previousTI3SHA256'] = digest(backup)
            (folder / 'chart.ti2').write_text(ti2, encoding='utf-8')
            save(folder / 'chartread-input.json', dict(chartJSONSHA256=chart_hash,
                 ti2SHA256=digest(folder / 'chart.ti2')))
            args = [data['executable'], '-v']
            tolerance = data.get('scanTolerance', 1.0)
            if not math.isfinite(tolerance) or tolerance <= 0:
                raise ValueError('Scan tolerance must be finite and positive')
            args += ['-T', format(tolerance, '.17g')]
            direction = data.get('direction', 'auto')
            if direction == 'forward':
                args.append('-B')
            elif direction == 'both':
                args.append('-b')
            elif direction != 'auto':
                raise ValueError('Invalid reading direction')
            if data['resume']:
                args.append('-r')
            if data['port']:
                args += ['-c', str(data['port'])]
            args.append('chart')
            version = subprocess.run([data['executable'], '-?'], capture_output=True, text=True, timeout=15)
            data.update(status='running', started=time.time(), arguments=args,
                        version=version.stdout + version.stderr,
                        ti2SHA256=digest(folder / 'chart.ti2'))
            save(record, data)
            for sig in (signal.SIGHUP, signal.SIGTERM, signal.SIGINT):
                old_handlers[sig] = signal.signal(sig, interrupted)
            print('\nInkProf - measurement in this terminal. MATLAB needs no poll/sendKey.\n'
                  'Follow chartread prompts. At the row prompt: b = previous row, '
                  'f = next row, n = next unread, d = save and finish.\n'
                  'Reread the selected row to replace its reading.\n', flush=True)
            # No pipes or synthetic PTY between chartread and the user's terminal.
            child = subprocess.Popen(args, cwd=folder)
            code = child.wait()
            data['exitCode'] = code
            changed = original.is_file() and (not data['resume'] or
                       digest(original) != data.get('previousTI3SHA256'))
            if changed:
                snapshot = folder / ('result-' + data['runId'] + '.ti3')
                with snapshot.open('xb') as f:
                    f.write(original.read_bytes())
                data.update(resultTI3=str(snapshot), resultSHA256=digest(snapshot))
            data['status'] = ('saved_unvalidated' if changed else 'no_new_result') if code == 0 else 'failed'
            data['validated'] = False
        except BaseException as error:
            data.update(status='interrupted' if isinstance(error, (InterruptedError, KeyboardInterrupt)) else 'failed',
                        error=str(error), validated=False)
        finally:
            if child is not None and child.poll() is None:
                child.terminate()
                try:
                    child.wait(timeout=3)
                except subprocess.TimeoutExpired:
                    child.kill()
                    child.wait()
            for sig, handler in old_handlers.items():
                signal.signal(sig, handler)
            data['ended'] = time.time()
            save(record, data)
    print('\nInkProf: ' + data['status'] + '\nResult record: ' + str(record), flush=True)
    if data.get('error'):
        print(data['error'], flush=True)
    return 0 if data['status'] in ('saved_unvalidated', 'no_new_result') else 1


def main():
    parser = argparse.ArgumentParser()
    sub = parser.add_subparsers(dest='operation', required=True)
    p = sub.add_parser('prepare')
    p.add_argument('folder');p.add_argument('executable')
    p.add_argument('--resume', action='store_true');p.add_argument('--port', type=int, default=0)
    p.add_argument('--scan-tolerance', type=float, default=1.0)
    p.add_argument('--direction', choices=['auto','forward','both'], default='auto')
    p = sub.add_parser('run');p.add_argument('record')
    args = parser.parse_args()
    if os.name != 'posix':
        parser.error('Terminal measurement currently supports macOS/Linux')
    if args.operation == 'prepare':
        if args.port < 0:
            parser.error('Port must be nonnegative')
        print(json.dumps(prepare(args.folder, args.executable, args.resume, args.port, args.scan_tolerance, args.direction)))
        return 0
    code = run(args.record)
    if sys.stdin.isatty():
        try:
            input('\nPress Return to close this measurement launcher. ')
        except (EOFError, KeyboardInterrupt):
            pass
    return code


if __name__ == '__main__':
    try:
        sys.exit(main())
    except Exception as error:
        print('InkProf: ' + str(error), file=sys.stderr)
        sys.exit(1)
