"""Shared FWA policy: native M0 spectra -> simulated D50, never relabel raw data."""
from pathlib import Path
import re


def arguments(color, condition, ti3):
    enabled = color.get('fwaCompensation', False)
    if type(enabled) is not bool:
        raise ValueError('FWA/OBA setting must be boolean.')
    if not enabled:
        return []
    if color.get('mode', 'spectral') != 'spectral' or color.get('fwaIlluminant') != 'D50':
        raise ValueError('FWA/OBA requires spectral data and simulated D50.')
    if (condition.get('interpreted') != 'M0' or not condition.get('instrument') or
            condition.get('instrumentFilter') == 'UVCUT' or condition.get('fwaApplied')):
        raise ValueError('FWA/OBA requires known native M0 measurements without UV filtering or prior compensation.')
    text = Path(ti3).read_text()
    instrument = re.search(r'^TARGET_INSTRUMENT\s+"([^"\n]+)"', text, re.M)
    if not instrument or instrument[1] != condition['instrument'] or re.search(r'^INSTRUMENT_FILTER\s+"?UVCUT', text, re.M):
        raise ValueError('FWA/OBA instrument metadata is missing or inconsistent in TI3.')
    fmt = re.search(r'BEGIN_DATA_FORMAT\s+(.*?)\s+END_DATA_FORMAT', text, re.S)
    data = re.search(r'BEGIN_DATA\s+(.*?)\s+END_DATA', text, re.S)
    fields = fmt[1].split() if fmt else []
    if not data or not any(f.startswith('SPEC_') or f.startswith('SPECTRAL_NM') for f in fields):
        raise ValueError('FWA/OBA requires spectral TI3 data.')
    try:
        indices = [fields.index(f'RGB_{c}') for c in 'RGB']
        import shlex
        white = any(all(abs(float(row[i])-100) < 1e-4 for i in indices)
                    for row in (shlex.split(line) for line in data[1].splitlines() if line.strip()))
    except (ValueError, IndexError) as exc:
        raise ValueError('Invalid FWA/OBA RGB data.') from exc
    if not white:
        raise ValueError('FWA/OBA requires a measured paper-white patch (RGB 100/100/100).')
    return ['-f', 'D50']
