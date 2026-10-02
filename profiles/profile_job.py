"""Owned colprof subprocess, cancellation and atomic job status (B3)."""
import argparse
import datetime
import hashlib
import json
import math
import os
from pathlib import Path
import shutil
import subprocess
import time
from read_icc import inspect_file
import sys
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "analysis"))
from fwa import arguments as fwa_arguments


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def write(path, record):
    stage = path.with_suffix('.tmp')
    stage.write_text(json.dumps(record, indent=2, ensure_ascii=False), encoding='utf-8')
    os.replace(stage, path)


def run(folder):
    folder = Path(folder).resolve()
    status = dict(schemaVersion=1, documentType='inkprof.profile-job', status='starting',
                  startedUTC=datetime.datetime.now(datetime.timezone.utc).isoformat(), profileFile=None)
    child = None
    def update(state):
        status['status'] = state
        status['updatedUTC'] = datetime.datetime.now(datetime.timezone.utc).isoformat()
        write(folder/'status.json', status)
    def stop():
        if child is not None and child.poll() is None:
            child.terminate()
            try: child.wait(timeout=3)
            except subprocess.TimeoutExpired:
                child.kill(); child.wait()
    def wait(timeout):
        start = time.monotonic()
        while child.poll() is None:
            if (folder/'cancel.request').exists():
                stop(); raise InterruptedError('Cancelled by user.')
            if time.monotonic()-start > timeout:
                stop(); raise TimeoutError('Profile job exceeded its time limit.')
            time.sleep(.1)
        if (folder/'cancel.request').exists():
            raise InterruptedError('Cancelled by user.')
        return child.returncode
    try:
        update('verifying')
        request = json.loads((folder/'request.json').read_text())
        for name, digest in request['files'].items():
            path = (folder/name).resolve()
            if not path.is_relative_to(folder) or sha(path) != digest:
                raise ValueError(f'Job input hash mismatch: {name}')
        recipe = json.loads((folder/'recipe.json').read_text())
        mode = recipe['colorimetry']['mode']
        if mode not in ('spectral', 'storedXYZ'):
            raise ValueError('Unsupported recipe colourimetry.')
        if recipe['engine']['quality'] not in ('medium', 'high') or recipe['engine']['algorithm'] != 'Lab cLUT':
            raise ValueError('Unsupported recipe algorithm/quality.')
        args = ['-qh' if recipe['engine']['quality']=='high' else '-qm', '-al']
        if mode == 'spectral':
            if recipe['colorimetry']['illuminant'] != 'D50' or recipe['colorimetry']['observer'] != '1931_2':
                raise ValueError('Unsupported spectral integration settings.')
            args += ['-i', 'D50', '-o', '1931_2']
        args += fwa_arguments(recipe['colorimetry'], recipe.get('measurementCondition', {}), folder/'engine.ti3')
        smoothing = recipe['engine'].get('smoothing')
        if smoothing is not None:
            if isinstance(smoothing, bool) or not isinstance(smoothing, (int,float)) or not math.isfinite(smoothing) or smoothing <= 0:
                raise ValueError('Invalid smoothing parameter.')
            args += ['-r', format(smoothing, '.17g')]
        # Legacy recipes omit this field and retain their exact original arguments.
        b2a = recipe['engine'].get('b2aQuality')
        if b2a is not None:
            if b2a not in ('medium', 'high'):
                raise ValueError('Unsupported B2A quality.')
            args += ['-bh' if b2a == 'high' else '-bm']
        args += ['-D', recipe['description']]
        if recipe['printing'].get('paperSurface') == 'Matte': args += ['-Z', 'm']
        if args != recipe['engine']['plannedArguments']:
            raise ValueError('Recipe planned arguments differ from implemented settings.')
        exe = str(Path(request['executable']).resolve())
        status['executable'] = exe
        status['executableSHA256'] = sha(exe)
        status['recipeSHA256'] = sha(folder/'recipe.json')
        status['arguments'] = ['-v', *args, 'engine']
        status['workingDirectory'] = 'work'
        status['inputPreparation'] = request['inputPreparation']
        work = folder/'work'; work.mkdir()
        shutil.copyfile(folder/'engine.ti3', work/'engine.ti3')
        status['engineTI3SHA256'] = sha(work/'engine.ti3')
        with (folder/'version.txt').open('wb') as log:
            child = subprocess.Popen([exe, '-?'], cwd=work, stdout=log, stderr=subprocess.STDOUT)
            rc = wait(15)
        if rc not in (0, 1): raise RuntimeError(f'colprof version query failed ({rc}).')
        status['versionOutput'] = (folder/'version.txt').read_text(errors='replace')
        update('running')
        with (folder/'colprof.log').open('wb') as log:
            child = subprocess.Popen([exe, *status['arguments']], cwd=work, stdout=log, stderr=subprocess.STDOUT)
            rc = wait(request.get('timeoutSeconds', 1800))
        status['exitCode'] = rc
        if rc != 0: raise RuntimeError(f'colprof failed (exit code {rc}); see colprof.log.')
        update('validating')
        candidates = [p for p in (work/'engine.icc', work/'engine.icm') if p.is_file()]
        if len(candidates) != 1: raise ValueError('Expected exactly one output ICC profile.')
        candidate = candidates[0]
        inspection = inspect_file(candidate)
        if not inspection['capabilities']['rgbOutputCandidate']:
            raise ValueError('Output is not an RGB output profile.')
        if inspection['diagnostics']:
            raise ValueError('Output ICC has A1 warnings; inspect quarantined work output.')
        tags = {t['signature'] for t in inspection['tags']}
        if not {'A2B0','B2A0'}.issubset(tags):
            raise ValueError('Output is missing expected LUT directions.')
        for name, digest in request['files'].items():
            if sha(folder/name) != digest: raise ValueError('Job input changed during execution.')
        if sha(work/'engine.ti3') != status['engineTI3SHA256']:
            raise ValueError('Engine input changed during execution.')
        if (folder/'cancel.request').exists(): raise InterruptedError('Cancelled before publication.')
        # Only validated output is placed in result; failed/cancelled candidates stay in work.
        stage = folder/'result-pending'; stage.mkdir()
        shutil.copyfile(candidate, stage/'profile.icc')
        inspection['source']['path'] = 'profile.icc'
        write(stage/'inspection.json', inspection)
        os.replace(stage, folder/'result')
        status['profileFile'] = 'result/profile.icc'
        status['profileSHA256'] = sha(folder/status['profileFile'])
        status['iccVersion'] = inspection['header']['version']
        status['qualityValidated'] = False
        update('succeeded')
    except InterruptedError as exc:
        status['error'] = str(exc); update('cancelled')
    except Exception as exc:
        status['error'] = str(exc); update('failed')
    finally:
        stop()
    return status


if __name__ == '__main__':
    p=argparse.ArgumentParser();p.add_argument('folder');a=p.parse_args();run(a.folder)
