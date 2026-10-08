# Copyright (c) 2026 Christer Törnkvist.
# SPDX-License-Identifier: GPL-3.0-or-later
# InkProf is free software under GNU GPL version 3 or later.
# Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
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


def _canonical_candidate(record):
    # MATLAB JSON round trips 380.0 as 380; hash numeric values, not spelling.
    import json,math
    def normalize(value):
        if isinstance(value,dict):return {k:normalize(v) for k,v in value.items()}
        if isinstance(value,list):return [normalize(v) for v in value]
        if isinstance(value,float) and math.isfinite(value) and value.is_integer():return int(value)
        return value
    return json.dumps(normalize(record),sort_keys=True,separators=(',',':'),allow_nan=False).encode()


def prepare(color, condition, ti3, output, spec2cie, profile_white_anchor=False):
    """Immutable native M0 -> simulated D50 XYZ using averaged measured white.

    Argyll spec2cie averages all device-white spectra. If absent, insert an
    explicitly approved blank-paper reference for conversion only, then remove
    that row. Never infer white from maxima of coloured patches.
    """
    import hashlib, json, math, shlex, subprocess
    source=Path(ti3); output=Path(output); output.mkdir(parents=True,exist_ok=True)
    if type(color.get('fwaCompensation',False)) is not bool:raise ValueError('FWA flag must be boolean.')
    if not color.get('fwaCompensation',False):return source,None
    if (color.get('mode','spectral')!='spectral' or color.get('fwaIlluminant')!='D50' or
        condition.get('interpreted')!='M0' or not condition.get('instrument') or
        condition.get('instrumentFilter')=='UVCUT' or condition.get('fwaApplied')):
        raise ValueError('FWA requires known native, unfiltered M0 spectra, not stored XYZ or previously compensated data.')
    def read(path):
        lines=Path(path).read_text().splitlines(); f0=lines.index('BEGIN_DATA_FORMAT');f1=lines.index('END_DATA_FORMAT');d0=lines.index('BEGIN_DATA');d1=lines.index('END_DATA')
        fields=' '.join(lines[f0+1:f1]).split();rows=[shlex.split(s) for s in lines[d0+1:d1] if s.strip()]
        if not rows or any(len(r)!=len(fields) for r in rows):raise ValueError('Invalid FWA spectral table.')
        return lines,fields,rows,f0,f1,d0,d1
    lines,fields,rows,f0,f1,d0,d1=read(source)
    instrument=re.search(r'^TARGET_INSTRUMENT\s+"([^"\n]+)"',source.read_text(),re.M)
    if not instrument or instrument[1]!=condition['instrument']:raise ValueError('FWA instrument metadata mismatch.')
    if re.search(r'^INSTRUMENT_FILTER\s+"?UVCUT',source.read_text(),re.M):raise ValueError('FWA data are UV filtered.')
    spectral=[(i,float(m[1])) for i,f in enumerate(fields) if (m:=re.fullmatch(r'(?:SPEC_|SPECTRAL_NM)(\d+(?:\.\d+)?)',f))]
    if len(spectral)<3 or min(w for _,w in spectral)>400 or max(w for _,w in spectral)<700:
        raise ValueError('FWA needs measured short-wave data at or below 400 nm and visible coverage to at least 700 nm. Blank paper cannot replace missing colour spectra.')
    rgb=[fields.index('RGB_'+c) for c in 'RGB']
    for row in rows:
        if any(not math.isfinite(float(row[i])) or float(row[i])<0 for i,_ in spectral):raise ValueError('Invalid native spectral values.')
        if any(not math.isfinite(float(row[i])) or not 0<=float(row[i])<=100 for i in rgb):raise ValueError('Invalid FWA device RGB.')
    # Same white criterion as Argyll RGB reflective media; disclose it.
    whites=[r for r in rows if all(float(r[i])>99.9 for i in rgb)]
    original_count=len(rows); added=False
    if whites:
        values=[[float(r[i]) for i,_ in spectral] for r in whites]
        mean=[sum(v[k] for v in values)/len(values) for k in range(len(spectral))]
        provenance=dict(source='current-target-white-patches',count=len(whites),sampleIds=[r[fields.index('SAMPLE_ID')] for r in whites])
    else:
        ref=color.get('paperWhiteReference')
        if not isinstance(ref,dict) or ref.get('approved') is not True:
            raise ValueError('No measured paper-white spectrum. Measure and approve blank paper of the same stock in B2; FWA cannot use maxima of coloured patches.')
        if ref.get('instrumentSerial') and condition.get('instrumentSerial') and ref['instrumentSerial']!=condition['instrumentSerial']:raise ValueError('Blank-paper instrument serial differs from the target.')
        if ref.get('instrument')!=condition['instrument'] or ref.get('measurementCondition')!='M0' or ref.get('spectralScale')!=100:
            raise ValueError('Blank-paper reference instrument/condition/scale differs from the target.')
        expected=[w for _,w in spectral]; waves=ref.get('wavelengthNm',[]); spectra=ref.get('meanSpectrum',[])
        if len(waves)!=len(expected) or any(abs(a-b)>1e-6 for a,b in zip(waves,expected)) or len(spectra)!=len(expected):raise ValueError('Blank-paper and target spectral wavelengths differ.')
        if not all(isinstance(v,(float,int)) and not isinstance(v,bool) and math.isfinite(v) and v>=0 for v in spectra):raise ValueError('Invalid blank-paper spectrum.')
        target_standard=re.search(r'^DEVCALSTD\s+"?([^"\s]+)',source.read_text(),re.M)
        if ref.get('calibrationStandard') and (not target_standard or target_standard[1]!=ref['calibrationStandard']):raise ValueError('Blank-paper calibration standard differs from the target.')
        readings=ref.get('readings',[])
        if isinstance(readings,dict):readings=[readings]
        if ref.get('sourceKind')=='locked-target-white':
            samples=ref.get('samples',[])
            if isinstance(samples,dict):samples=[samples]
            if not samples or ref.get('count')!=len(samples) or not re.fullmatch('[0-9a-f]{64}',ref.get('sourceTI3SHA256','')):raise ValueError('Invalid locked-target white provenance.')
            if any(len(r.get('spectrum',[]))!=len(expected) or not all(math.isfinite(v) and v>=0 for v in r['spectrum']) for r in samples):raise ValueError('Invalid white sample spectra.')
            calc=[sum(r['spectrum'][k] for r in samples)/len(samples) for k in range(len(expected))]
            if any(abs(a-b)>1e-8 for a,b in zip(calc,spectra)):raise ValueError('Locked-target white mean does not match samples.')
            readings=None
        if readings is not None and (not readings or ref.get('count')!=len(readings)):raise ValueError('Blank-paper reference has no traceable readings.')
        for record in (readings or []):
            candidate=record.get('candidate',{})
            canonical=_canonical_candidate(candidate)
            if hashlib.sha256(canonical).hexdigest()!=record.get('candidateSHA256'):raise ValueError('Blank-paper reading checksum mismatch.')
            if candidate.get('wavelengthNm')!=waves or candidate.get('spectralScale')!=100 or candidate.get('calibrationStandard')!=ref.get('calibrationStandard') or not candidate.get('measurementCondition','').startswith('M0') or candidate.get('mode')!='native reflection; no FWA':raise ValueError('Invalid blank-paper reading provenance.')
        if readings is not None:calc=[sum(r['candidate']['spectra'][k] for r in readings)/len(readings) for k in range(len(expected))]
        if any(abs(a-b)>1e-8 for a,b in zip(calc,spectra)):raise ValueError('Blank-paper mean does not match source readings.')
        mean=list(spectra);provenance=dict(source='saved-profiling-white-reference' if readings is None else 'approved-blank-paper',count=ref['count'],reference=ref)
        row=['0']*len(fields)
        for i in rgb:row[i]='100'
        row[fields.index('SAMPLE_ID')]='INKPROF_FWA_WHITE_REFERENCE'
        if 'SAMPLE_LOC' in fields:row[fields.index('SAMPLE_LOC')]='INKPROF_FWA_WHITE_REFERENCE'
        for (i,_),v in zip(spectral,mean):row[i]=format(v,'.17g')
        rows.append(row);added=True
    def render(lines,fields,rows,f0,f1,d0,d1):
        quote=lambda v: '"'+str(v).replace('"','')+'"' if not re.fullmatch(r'[-+0-9.eE]+',str(v)) else str(v)
        before=lines[:f0];before=[re.sub(r'^NUMBER_OF_FIELDS\s+.*','NUMBER_OF_FIELDS '+str(len(fields)),s) for s in before]
        middle=[re.sub(r'^NUMBER_OF_SETS\s+.*','NUMBER_OF_SETS '+str(len(rows)),s) for s in lines[f1+1:d0]]
        def cell(field,value):
            if field.startswith(('RGB_','XYZ_','LAB_','SPEC_','SPECTRAL_NM')):
                number=format(float(value),'.17g');return number if any(c in number for c in '.eE') else number+'.0'
            return quote(value)
        return '\n'.join(before+['BEGIN_DATA_FORMAT',' '.join(fields),'END_DATA_FORMAT']+middle+['BEGIN_DATA']+[' '.join(cell(f,v) for f,v in zip(fields,r)) for r in rows]+['END_DATA']+lines[d1+1:])+'\n'
    prepared=output/'native-with-white.ti3';prepared.write_text(render(lines,fields,rows,f0,f1,d0,d1))
    converted=output/'compensated-all.ti3';exe=Path(spec2cie).resolve()
    if not exe.is_file():raise ValueError('spec2cie is required for FWA preparation.')
    args=['-v','-n','-i','D50','-o','1931_2','-f','D50',str(prepared.resolve()),str(converted.resolve())]
    proc=subprocess.run([str(exe),*args],capture_output=True,timeout=180)
    log=proc.stdout+proc.stderr;(output/'spec2cie-fwa.log').write_bytes(log)
    if proc.returncode or not converted.is_file():raise ValueError('FWA integration failed; see spec2cie-fwa.log.')
    ll,ff,rr,aa,bb,cc,dd=read(converted)
    if len(rr)!=len(rows):raise ValueError('FWA conversion changed sample count.')
    identity=['SAMPLE_ID','RGB_R','RGB_G','RGB_B']+(['SAMPLE_LOC'] if 'SAMPLE_LOC' in fields else [])
    for original,new in zip(rows,rr):
        for key in identity:
            a=original[fields.index(key)];b=new[ff.index(key)]
            if (key.startswith('RGB_') and abs(float(a)-float(b))>1e-5) or (not key.startswith('RGB_') and a!=b):raise ValueError('FWA conversion changed sample identity.')
    if any(f.startswith(('SPEC_','SPECTRAL_NM')) for f in ff):raise ValueError('FWA converted input must be XYZ only.')
    for r in rr:
        if any(not math.isfinite(float(r[ff.index('XYZ_'+c)])) for c in 'XYZ'):raise ValueError('Nonfinite compensated XYZ.')
    reference_xyz=[float(rr[-1][ff.index('XYZ_'+c)]) for c in 'XYZ'] if added else None
    if not (added and profile_white_anchor):rr=rr[:original_count]
    target=output/'compensated.ti3';target.write_text(render(ll,ff,rr,aa,bb,cc,dd))
    digest=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest()
    evidence=dict(schemaVersion=1,documentType='inkprof.fwa-preparation',method='Argyll spec2cie native M0 to simulated D50 XYZ; compensation once',sourceTI3SHA256=digest(source),compensatedTI3SHA256=digest(target),toolSHA256=digest(exe),arguments=args,white=provenance,wavelengthNm=[w for _,w in spectral],meanWhiteSpectrum=mean,whiteCriterion='all RGB channels > 99.9 percent',whiteSpectrumSampleStdDev=[(sum((v[k]-mean[k])**2 for v in values)/(len(values)-1))**0.5 for k in range(len(mean))] if whites and len(values)>1 else None,measurementCondition=condition,limitations='M0-based fluorescence estimate, not direct UV excitation measurement or native M1. Averaging reduces random variation but cannot recover missing UV excitation. A weak fluorescence signal may remain uncertain.',addedReferenceExcludedFromFit=added and not profile_white_anchor,additionalProfileWhiteAnchor=added and profile_white_anchor,referenceWhiteXYZ=reference_xyz)
    (output/'fwa-preparation.json').write_text(json.dumps(evidence,indent=2,allow_nan=False))
    return target,evidence


def reference_from_candidates(candidates):
    """Create an operator-approved reference from already validated spot candidates."""
    import hashlib,json,math
    readings=[json.loads(Path(p).read_text()) for p in candidates]
    if not readings:raise ValueError('Measure at least one blank-paper location.')
    first=readings[0];waves=first['wavelengthNm']
    for r in readings:
        if (r.get('documentType')!='inkprof.spot-candidate' or r.get('wavelengthNm')!=waves or r.get('spectralScale')!=100 or
            r.get('calibrationStandard')!=first.get('calibrationStandard') or r.get('instrumentSerial')!=first.get('instrumentSerial') or
            not r.get('measurementCondition','').startswith('M0') or r.get('mode')!='native reflection; no FWA' or
            len(r.get('spectra',[]))!=len(waves) or not all(math.isfinite(x) and x>=0 for x in r['spectra'])):
            raise ValueError('Blank-paper readings have incompatible instrument, condition or spectral data.')
        evidence=r.get('instrumentEvidence','')
        if 'X-Rite i1 Pro 2' not in evidence or not re.search(r'U\.V\. filter \?\s*:\s*No',evidence):raise ValueError('Missing native i1Pro2 instrument evidence.')
    if min(waves)>400 or max(waves)<700:raise ValueError('Blank-paper spectrum lacks short-wave/visible coverage.')
    records=[dict(candidate=r,candidateSHA256=hashlib.sha256(_canonical_candidate(r)).hexdigest()) for r in readings]
    return dict(schemaVersion=1,documentType='inkprof.paper-white-reference',approved=True,measurementCondition='M0',instrument='X-Rite i1 Pro 2',instrumentSerial=first.get('instrumentSerial',''),calibrationStandard=first['calibrationStandard'],spectralScale=100,wavelengthNm=waves,count=len(readings),meanSpectrum=[sum(r['spectra'][i] for r in readings)/len(readings) for i in range(len(waves))],readings=records,scope='Operator confirms same blank paper, stock and backing as target; no ink. Native M0 estimate, not measured M1.')


if __name__=='__main__':
    import argparse,json
    p=argparse.ArgumentParser();p.add_argument('--output',required=True);p.add_argument('candidates',nargs='+');a=p.parse_args()
    Path(a.output).write_text(json.dumps(reference_from_candidates(a.candidates),indent=2,allow_nan=False))
