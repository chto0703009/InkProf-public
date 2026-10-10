# Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
# Copyright (c) 2026 Christer Törnkvist.
# SPDX-License-Identifier: GPL-3.0-or-later
"""Manually triggered control spots in one persistent calibrated session."""
import argparse, codecs, fcntl, json, os, pty, re, selectors, signal, subprocess, sys, time
from pathlib import Path
from pty_transport import read_ready
from spotread_bridge import parse_reading, prompt_state, emit


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('folder'); parser.add_argument('executable')
    args = parser.parse_args(); folder = Path(args.folder).resolve()
    request = json.loads((folder / 'request.json').read_text())
    if request.get('documentType') != 'inkprof.print-control-test' or not request.get('readings'):
        raise ValueError('Expected a nonempty print control test.')
    if list(folder.glob('reading-*.json')):
        raise ValueError('Use a new test folder; existing readings are preserved.')
    standard = {'XRGA': 'G', 'XRDI': 'X', 'GMDI': 'A'}[request['calibrationStandard']]
    command = [str(Path(args.executable).resolve()), '-v', '-s', '-i', 'D50', '-Q', '1931_2', '-A', standard]
    if request.get('port'): command += ['-c', str(request['port'])]
    run = dict(arguments=command, started=time.time(), autoTrigger=False, sameSession=True)
    lock = open(Path('/tmp') / f'inkprof-spot-{os.getuid()}.lock', 'a')
    fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
    master, slave = pty.openpty(); proc = None; sel = None
    state = 'busy'; buffer = ''; full = ''; pending = b''; count = 0
    quitting = False; quit_confirmed = False; deadline = time.monotonic() + 1800
    decoder = codecs.getincrementaldecoder('utf-8')('replace')
    try:
        proc = subprocess.Popen(command, cwd=folder, stdin=slave, stdout=slave, stderr=slave, start_new_session=True)
        os.close(slave); slave = None
        sel = selectors.DefaultSelector(); sel.register(master, selectors.EVENT_READ, 'output'); sel.register(sys.stdin, selectors.EVENT_READ, 'input')
        with (folder / 'transcript.txt').open('wb') as log:
            alive = True
            while alive:
                if time.monotonic() > deadline: raise RuntimeError('Control test timed out.')
                for key, _ in sel.select(.1):
                    if key.data == 'output':
                        data = read_ready(master, pty_output=True)
                        if data is None: continue
                        if not data: alive = False; break
                        log.write(data); log.flush()
                        text = decoder.decode(data); full += text; buffer += text; emit('output', text=text)
                        new = prompt_state(buffer)
                        if new == 'ready' and 'Result is XYZ:' in buffer and not quitting:
                            candidate = parse_reading(buffer)
                            evidence = full[:full.find('Result is XYZ:')]
                            if not re.search(r'Instrument Type:\s*X-Rite i1 Pro 2', evidence) or not re.search(r'U\.V\. filter \?\s*:\s*No', evidence):
                                raise ValueError('Confirmed native i1 Pro 2 M0 is required.')
                            serial = re.search(r'Serial Number:\s*(\S+)', evidence)
                            if request.get('instrumentSerial') and (not serial or serial[1] != request['instrumentSerial']):
                                raise ValueError('Instrument serial differs from the original measurements.')
                            candidate.update(schemaVersion=1, documentType='inkprof.control-reading',
                                             request=request['readings'][count], instrumentSerial=serial[1] if serial else '',
                                             measurementCondition='M0', calibrationStandard=request['calibrationStandard'])
                            count += 1; path = folder / f'reading-{count:03d}.json'
                            with path.open('x') as handle: json.dump(candidate, handle, indent=2, allow_nan=False)
                            emit('candidate', path=str(path), index=count)
                            buffer = ''; state = 'ready'
                            if count == len(request['readings']):
                                quitting = True; os.write(master, b'q'); deadline = time.monotonic() + 10
                            else:
                                emit('state', kind='ready'); deadline = time.monotonic() + 1800
                        elif quitting and not quit_confirmed and re.search(r'Hit Esc or Q to give up, any other key to retry:\s*$', buffer):
                            quit_confirmed = True; buffer = ''; os.write(master, b'q')
                        elif not quitting and new != state:
                            state = new; emit('state', kind=state)
                    else:
                        data = read_ready(sys.stdin.fileno())
                        if data is None: continue
                        if not data: raise RuntimeError('Controller disconnected; saved spots are preserved.')
                        pending += data
                        while b'\n' in pending:
                            line, pending = pending.split(b'\n', 1); msg = json.loads(line)
                            if msg.get('command') == 'stop': raise RuntimeError('Cancelled; saved spots are preserved.')
                            if quitting or msg.get('command') != 'key' or msg.get('text') != ' ' or state not in ('calibration', 'calibrationRetry', 'ready', 'retry'):
                                raise ValueError('Command does not match an instrument prompt.')
                            os.write(master, b' '); buffer = ''; state = 'busy'; emit('state', kind=state)
        code = proc.wait(timeout=5)
        if code != 0 or count != len(request['readings']): raise RuntimeError('Control test ended before all spots were recorded.')
        emit('completed', count=count)
    finally:
        if proc is not None and proc.poll() is None:
            os.killpg(proc.pid, signal.SIGTERM)
            try: proc.wait(timeout=2)
            except subprocess.TimeoutExpired: os.killpg(proc.pid, signal.SIGKILL); proc.wait()
        if sel is not None: sel.close()
        if slave is not None: os.close(slave)
        os.close(master); lock.close()
        run.update(ended=time.time(), exitCode=proc.returncode if proc else None, recorded=count)
        (folder / 'run.json').write_text(json.dumps(run, indent=2))

if __name__ == '__main__':
    try: main()
    except Exception as error: emit('error', message=str(error)); sys.exit(1)
