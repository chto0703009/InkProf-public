# Copyright (c) 2026 Christer Törnkvist.
# SPDX-License-Identifier: GPL-3.0-or-later
# InkProf is free software under GNU GPL version 3 or later.
# Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
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
from fwa import arguments as fwa_arguments, prepare as fwa_prepare
import preregularize


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
    def launch(command, log, cwd):
        nonlocal child
        child = subprocess.Popen([str(c) for c in command], cwd=cwd, stdout=log, stderr=subprocess.STDOUT)
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
        pre = preregularize.settings(recipe)
        quality_args = ['-qh' if recipe['engine']['quality']=='high' else '-qm']
        colour_args = []
        prepared_fwa = recipe['colorimetry'].get('fwaCompensation') and recipe['colorimetry'].get('fwaPreparation')=='white-reference-spec2cie-v1'
        if mode == 'spectral' and not prepared_fwa:
            if recipe['colorimetry']['illuminant'] != 'D50' or recipe['colorimetry']['observer'] != '1931_2':
                raise ValueError('Unsupported spectral integration settings.')
            colour_args = ['-i', 'D50', '-o', '1931_2']
        # With pre-regularization, spectra are integrated in pass 1 only; pass 2
        # reads the derived XYZ build input.
        args = [*quality_args, '-al', *([] if pre else colour_args)]
        if not prepared_fwa:
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
        mapping = recipe['engine'].get('gamutMapping')
        if isinstance(mapping, dict):
            compression = mapping.get('compressionPercent')
            if mapping.get('method') != 'generic-compression' or isinstance(compression, bool) or not isinstance(compression, (int, float)) or not math.isfinite(compression) or compression <= 0:
                raise ValueError('Invalid perceptual gamut mapping settings.')
            args += ['-s', format(compression, '.17g')]
        args += ['-D', recipe['description']]
        if recipe['printing'].get('paperSurface') == 'Matte': args += ['-Z', 'm']
        shadow = recipe['engine'].get('shadow', {})
        shadow_args = []
        if shadow.get('enabled', False):
            emphasis = shadow.get('gridEmphasis')
            if recipe['printing'].get('paperSurface', '').lower() != 'matte' or isinstance(emphasis, bool) or not isinstance(emphasis, (int, float)) or not math.isfinite(emphasis) or not 1 <= emphasis <= 3:
                raise ValueError('Invalid matte shadow emphasis.')
            shadow_args = ['-V', format(emphasis, '.17g')]
            args += shadow_args
        if args != recipe['engine']['plannedArguments']:
            raise ValueError('Recipe planned arguments differ from implemented settings.')
        if pre and pre['method'] == preregularize.METHOD:
            pre_args = preregularize.pass1_arguments(quality_args, colour_args, pre['avgdev'], shadow_args)
            if pre_args != pre.get('plannedArguments'):
                raise ValueError('Recipe pre-regularization arguments differ from implemented settings.')
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
        if prepared_fwa:
            converted,evidence=fwa_prepare(recipe['colorimetry'],recipe.get('measurementCondition',{}),folder/'engine.ti3',folder/'fwa',Path(exe).with_name('spec2cie'+Path(exe).suffix),profile_white_anchor=True)
            status['fwaPreparation']=evidence
            shutil.copyfile(converted,work/'engine.ti3')
            status['compensatedTI3SHA256']=sha(work/'engine.ti3')
        with (folder/'version.txt').open('wb') as log:
            launch([exe, '-?'], log, work)
            rc = wait(15)
        if rc not in (0, 1): raise RuntimeError(f'colprof version query failed ({rc}).')
        status['versionOutput'] = (folder/'version.txt').read_text(errors='replace')
        stem = 'engine'
        if pre:
            stem = 'derived'
            status['arguments'] = ['-v', *args, stem]
            status['preRegularization'] = run_preregularization(
                folder, work, exe, pre, pre_args, colour_args, wait, update, request.get('timeoutSeconds', 1800),
                launch)
            shutil.copyfile(folder/'preregularization'/'derived.ti3', work/'derived.ti3')
            if sha(work/'derived.ti3') != status['preRegularization']['derivedTI3SHA256']:
                raise ValueError('Derived build input changed while copying.')
        status['buildTI3'] = 'preregularization/derived.ti3' if pre else ('fwa/compensated.ti3' if prepared_fwa else 'engine.ti3')
        status['buildTI3SHA256'] = sha(work/f'{stem}.ti3')
        update('running')
        with (folder/'colprof.log').open('wb') as log:
            launch([exe, *status['arguments']], log, work)
            rc = wait(request.get('timeoutSeconds', 1800))
        status['exitCode'] = rc
        if rc != 0: raise RuntimeError(f'colprof failed (exit code {rc}); see colprof.log.')
        update('validating')
        candidates = [p for p in (work/f'{stem}.icc', work/f'{stem}.icm') if p.is_file()]
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
        if isinstance(mapping, dict):
            required = {'A2B0', 'B2A0', 'B2A1', 'wtpt'}
            if not required.issubset(tags):
                raise ValueError('Output is missing perceptual/relative tables or media white for absolute intent.')
            tables = {t['signature']: t for t in inspection['tags']}
            white = tables['wtpt'].get('decoded')
            if tables['wtpt']['type'] != 'XYZ ' or not isinstance(white, list) or len(white) != 1 or len(white[0]) != 3 or not all(math.isfinite(v) and v > 0 for v in white[0]):
                raise ValueError('Invalid media white for absolute colorimetric intent.')
            if tables['B2A0']['offset'] == tables['B2A1']['offset']:
                raise ValueError('Perceptual and relative tables share the same data; gamut mapping was not generated.')
            status['renderingIntents'] = dict(perceptual='B2A0, generic gamut compression', relative='B2A1', absolute='B2A1 plus media white (wtpt)', compressionPercent=compression)
        for name, digest in request['files'].items():
            if sha(folder/name) != digest: raise ValueError('Job input changed during execution.')
        if sha(work/'engine.ti3') != status.get('compensatedTI3SHA256',status['engineTI3SHA256']) or sha(work/f'{stem}.ti3') != status['buildTI3SHA256']:
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


def run_preregularization(folder, work, exe, pre, pre_args, colour_args, wait, update, timeout, launch):
    """Pass 1 + profcheck evaluation. Publishes preregularization/ atomically."""
    update('pre-regularizing')
    pre_work = work/'pre'; pre_work.mkdir()
    shutil.copyfile(work/'engine.ti3', pre_work/'pre.ti3')
    raw_hash = sha(pre_work/'pre.ti3')
    profcheck = Path(exe).with_name('profcheck' + Path(exe).suffix)
    if not profcheck.is_file():
        raise ValueError('profcheck was not found next to colprof; it is required for pre-regularization.')
    with (folder/'colprof-pre.log').open('wb') as log:
        launch([exe, '-v', *pre_args, 'pre'], log, pre_work)
        rc = wait(timeout)
    if rc != 0: raise RuntimeError(f'Pre-regularization colprof failed (exit code {rc}); see colprof-pre.log.')
    models = [p for p in (pre_work/'pre.icc', pre_work/'pre.icm') if p.is_file()]
    if len(models) != 1: raise ValueError('Expected exactly one pre-regularization model profile.')
    check_args = ['-v2', '-k', '-I', 'a', *colour_args]
    with (folder/'profcheck-pre.log').open('wb') as log:
        launch([profcheck, *check_args, 'pre.ti3', models[0].name], log, pre_work)
        rc = wait(min(timeout, 600))
    if rc != 0: raise RuntimeError(f'profcheck failed (exit code {rc}); see profcheck-pre.log.')
    table = preregularize.read_ti3((pre_work/'pre.ti3').read_text())
    model_lab, measured_lab, reported = preregularize.parse_profcheck((folder/'profcheck-pre.log').read_text(errors='replace'), table)
    xyz = [preregularize.lab_to_xyz(lab) for lab in model_lab]
    result = preregularize.comparison(table, model_lab, measured_lab, reported, pre['avgdev'])
    if sha(pre_work/'pre.ti3') != raw_hash or sha(work/'engine.ti3') != raw_hash:
        raise ValueError('Raw measurement input changed during pre-regularization.')
    stage = folder/'preregularization-pending'; stage.mkdir()
    shutil.copyfile(models[0], stage/'model.icc')
    (stage/'derived.ti3').write_text(preregularize.derived_ti3(table, xyz, pre['avgdev']))
    derived = preregularize.read_ti3((stage/'derived.ti3').read_text())
    if derived['ids'] != table['ids'] or derived['locations'] != table['locations'] or derived['rgb'] != table['rgb']:
        raise ValueError('Derived TI3 changed patch identities or RGB positions.')
    result['rawTI3SHA256'] = sha(folder/'engine.ti3')
    result['referenceTI3SHA256'] = raw_hash
    result['derivedTI3SHA256'] = sha(stage/'derived.ti3')
    result['modelProfileSHA256'] = sha(stage/'model.icc')
    write(stage/'patch-comparison.json', result)
    (stage/'patch-comparison.md').write_text(preregularize.markdown(result), encoding='utf-8')
    os.replace(stage, folder/'preregularization')
    return dict(method=pre['method'], avgdev=pre['avgdev'], arguments=['-v', *pre_args, 'pre'],
                profcheck=str(profcheck), profcheckSHA256=sha(profcheck), profcheckArguments=check_args,
                rawTI3SHA256=sha(folder/'engine.ti3'), referenceTI3SHA256=raw_hash, derivedTI3SHA256=result['derivedTI3SHA256'],
                modelProfileSHA256=result['modelProfileSHA256'], comparison='preregularization/patch-comparison.json',
                summary=result['summary'],
                note='Final profile is built from derived model values at the original device RGB; raw measurements are unchanged and remain the reference for fit reports.')


if __name__ == '__main__':
    p=argparse.ArgumentParser();p.add_argument('folder');a=p.parse_args();run(a.folder)
