# Synthetic UI test only; never contacts a measuring instrument.
import json
import os
from pathlib import Path
import sys
import time
import tty
if '-?' in sys.argv:
    print('Fake chartread dialog 1.0')
    sys.exit(1)
tty.setraw(sys.stdin.fileno())
def prompt(text):
    print(text, flush=True)
def key(expected):
    k=os.read(sys.stdin.fileno(), 1).decode()
    with open('keys.txt', 'a') as f: f.write(k)
    assert k == expected, (k,expected)
def instrument_button():
    # A file models the hardware switch, independently of GUI stdin keys.
    trigger = Path('instrument-button')
    deadline = time.monotonic() + 25
    while not trigger.exists():
        if time.monotonic() > deadline:
            raise TimeoutError('Waiting for simulated instrument button')
        time.sleep(.02)
    trigger.unlink()
row='Ready to read strip pass 1\nTrigger instrument switch or any other key to start:'
prompt('Place the instrument on its reflective white reference S/N TEST,\nor hit Esc or Q to abort:')
key(' ')
# Calibration can fail repeatedly; retry must stay in the same session.
for attempt in range(2):
    prompt("Calibration failed with 'Measurement misread' (White reference reading is out of tollerance)\nHit any key to retry, or Esc or Q to abort:")
    key(' ')
# Fragmented output, including a delay, must not enable premature actions.
print('Calibration complete\nReady to read strip pass 1\nTrigger instrument switch or any other key to sta',end='',flush=True)
time.sleep(.35)
prompt('rt:')
instrument_button()
prompt('Strip read failed due to misread (Too many patches)\nHit Esc to give up, any other key to retry:')
key(' ')
prompt(row)
instrument_button()
if Path.cwd().name == 'paired':
    prompt('Strip read OK\nReady to read strip pass 2\nTrigger instrument switch or any other key to start:')
    instrument_button()
prompt('Strip read OK\nReady to read strip pass 1 (!! ALL ROWS READ !!)\nTrigger instrument switch or any other key to start:')
key('d')
chart=json.loads(Path('chart.json').read_text())
p=[x for x in chart['patches'] if not x['isPadding']]
lines=['CTI3','COLOR_REP "RGB_XYZ"','NUMBER_OF_FIELDS 10','BEGIN_DATA_FORMAT','SAMPLE_ID SAMPLE_LOC RGB_R RGB_G RGB_B XYZ_X XYZ_Y XYZ_Z SPEC_400 SPEC_500','END_DATA_FORMAT',f'NUMBER_OF_SETS {len(p)}','BEGIN_DATA']
for x in p: lines.append(' '.join([x['sampleId'],x['sampleLoc']]+[str(v) for v in x['rgbPercent']]+['10','20','30','10','20']))
lines.append('END_DATA')
Path('chart.ti3').write_text('\n'.join(lines)+'\n')
