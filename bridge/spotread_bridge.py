# Copyright (c) 2026 Christer Törnkvist.
# SPDX-License-Identifier: GPL-3.0-or-later
# InkProf is free software under GNU GPL version 3 or later.
# Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
"""InkProf single-patch reflectance transport (POSIX, standard library only).
Workflow and spectral block interpretation informed by SpectraLab v1.2.1-dev
spotread_manual_measure.py and Parser.m (GPL-3.0); own transport/strict parser.
No calibration or measurement key is sent automatically. After one full reading
and its following prompt, quit spotread and publish a candidate for review.
"""
import argparse,codecs,json,math,os,re,selectors,signal,subprocess,sys,time
from pathlib import Path
from pty_transport import read_ready
NUMBER=r'[-+]?(?:\d+(?:\.\d*)?|\.\d+)(?:[eE][-+]?\d+)?'

def emit(event,**data):print(json.dumps(dict(event=event,**data)),flush=True)

def parse_reading(text):
    spectra=list(re.finditer(r'Spectrum from\s+('+NUMBER+r')\s+to\s+('+NUMBER+r')\s+nm in\s+(\d+)\s+steps\s*(.*?)(?=Peak value|Result is XYZ|Hit .*take a reading:|$)',text,re.S))
    xyz=list(re.finditer(r'Result is XYZ:\s*('+NUMBER+r')\s+('+NUMBER+r')\s+('+NUMBER+r')\s*,\s*D50\s+Lab:\s*('+NUMBER+r')\s+('+NUMBER+r')\s+('+NUMBER+r')',text))
    if len(spectra)!=1 or len(xyz)!=1:raise ValueError('Expected exactly one complete spectral and D50 XYZ reading.')
    s=spectra[0];lo,hi=float(s[1]),float(s[2]);n=int(s[3]);values=[float(x) for x in re.findall(NUMBER,s[4])]
    if n<3 or n>1000 or hi<=lo or len(values)!=n or not all(math.isfinite(x) for x in values):raise ValueError('Incomplete or invalid spectrum; no candidate accepted.')
    coordinates=[float(x) for x in xyz[0].groups()]
    if not all(math.isfinite(x) for x in coordinates):raise ValueError('Invalid XYZ/Lab.')
    return dict(wavelengthNm=[lo+i*(hi-lo)/(n-1) for i in range(n)],spectra=values,xyz=coordinates[:3],lab=coordinates[3:],spectralScale=100,illuminant='D50',observer='1931_2')

def prompt_state(text):
    text=text.replace('\r','')
    if re.search(r'Hit any key to retry, or Esc or Q to abort:\s*$',text):return 'calibrationRetry' if re.search('calibration',text,re.I) else 'retry'
    if 'white reference' in text and re.search(r'or hit Esc or Q to abort:\s*$',text):return 'calibration'
    if re.search(r'(?:Hit|hit) ESC or Q to exit.*take a reading:\s*$',text,re.S):return 'ready'
    if re.search(r'(?:Hit|hit) Esc to give up, any other key to retry:\s*$',text):return 'retry'
    return 'busy'

def main():
    import pty,fcntl
    parser=argparse.ArgumentParser();parser.add_argument('folder');parser.add_argument('executable');args=parser.parse_args()
    folder=Path(args.folder).resolve();request=json.loads((folder/'request.json').read_text())
    if (folder/'candidate.json').exists():raise ValueError('Candidate already exists; create a new attempt.')
    # Same conversion standard as the original TI3, never inherit an environment override.
    standard={'XRGA':'G','XRDI':'X','GMDI':'A'}[request['calibrationStandard']]
    command=[str(Path(args.executable).resolve()),'-v','-s','-i','D50','-Q','1931_2','-A',standard]
    if request.get('port',0):command+=['-c',str(request['port'])]
    run={'arguments':command,'started':time.time(),'mode':'reflection','autoTrigger':False}
    (folder/'run.json').write_text(json.dumps(run,indent=2))
    lock=open(Path('/tmp')/f'inkprof-spot-{os.getuid()}.lock','a');fcntl.flock(lock,fcntl.LOCK_EX|fcntl.LOCK_NB)
    master,slave=pty.openpty();proc=None;candidate=None;state='busy';buffer='';full='';pending=b'';quitting=False;quit_confirmed=False;deadline=time.monotonic()+900
    decoder=codecs.getincrementaldecoder('utf-8')('replace')
    try:
        proc=subprocess.Popen(command,cwd=folder,stdin=slave,stdout=slave,stderr=slave,start_new_session=True);os.close(slave);slave=None
        sel=selectors.DefaultSelector();sel.register(master,selectors.EVENT_READ,'output');sel.register(sys.stdin,selectors.EVENT_READ,'input')
        with (folder/'transcript.txt').open('wb') as log:
            alive=True
            while alive:
                if time.monotonic()>deadline:raise RuntimeError('Spot measurement timed out.')
                for key,_ in sel.select(.1):
                    if key.data=='output':
                        data=read_ready(master,pty_output=True)
                        if data is None:continue
                        if not data:alive=False;break
                        log.write(data);log.flush();text=decoder.decode(data);full+=text;buffer+=text;emit('output',text=text)
                        new=prompt_state(buffer)
                        if new=='ready' and 'Result is XYZ:' in full and not quitting:
                            candidate=parse_reading(full);quitting=True;buffer='';os.write(master,b'q');deadline=time.monotonic()+10
                        elif quitting and not quit_confirmed and re.search(r'Hit Esc or Q to give up, any other key to retry:\s*$',buffer):
                            # i1Pro 2 may treat the first q as aborting a pending spot read,
                            # then ask whether to retry. Confirm exit, never trigger a retry.
                            quit_confirmed=True;buffer='';os.write(master,b'q');deadline=time.monotonic()+10
                        elif new!=state and not quitting:state=new;emit('state',kind=state)
                    else:
                        data=read_ready(sys.stdin.fileno())
                        if data is None:continue
                        if not data:raise RuntimeError('Controller disconnected.')
                        pending+=data
                        while b'\n' in pending:
                            line,pending=pending.split(b'\n',1);msg=json.loads(line)
                            if msg.get('command')=='stop':raise RuntimeError('Cancelled by user.')
                            if msg.get('command')!='key' or msg.get('text')!=' ' or state not in ('calibration','calibrationRetry','ready','retry'):raise ValueError('Command does not match a complete instrument prompt.')
                            os.write(master,b' ');buffer='';state='busy';emit('state',kind=state)
        code=proc.wait(timeout=5)
        if code!=0 or candidate is None:raise RuntimeError('Spotread ended without one valid spectral reading.')
        evidence=full[:full.find('Result is XYZ:')]
        if not re.search(r'Instrument Type:\s*X-Rite i1 Pro 2',evidence) or not re.search(r'U\.V\. filter \?\s*:\s*No',evidence):raise ValueError('This first implementation requires confirmed i1 Pro 2 native unfiltered reflection (M0).')
        serial=re.search(r'Serial Number:\s*(\S+)',evidence)
        if request.get('instrumentSerial') and (not serial or serial[1]!=request['instrumentSerial']):raise ValueError('Instrument serial differs from the original measurement.')
        candidate.update(instrumentSerial=serial[1] if serial else '',measurementCondition='M0 (inferred from i1 Pro 2 native unfiltered reflection)',schemaVersion=1,documentType='inkprof.spot-candidate',request=request,calibrationStandard=request['calibrationStandard'],mode='native reflection; no FWA',instrumentEvidence=full[:full.find('Spectrum from')],created=time.time())
        with (folder/'candidate.json').open('x') as handle:json.dump(candidate,handle,indent=2,allow_nan=False)
        emit('candidate',path=str(folder/'candidate.json'))
    finally:
        if proc is not None and proc.poll() is None:
            os.killpg(proc.pid,signal.SIGTERM)
            try:proc.wait(timeout=2)
            except subprocess.TimeoutExpired:os.killpg(proc.pid,signal.SIGKILL);proc.wait()
        if slave is not None:os.close(slave)
        os.close(master);lock.close()
        run.update(ended=time.time(),exitCode=proc.returncode if proc else None,candidateExists=(folder/'candidate.json').exists())
        (folder/'run.json').write_text(json.dumps(run,indent=2))

if __name__=='__main__':
    try:main()
    except Exception as error:emit('error',message=str(error));sys.exit(1)
