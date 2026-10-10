# Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
#!/usr/bin/env python3
# Copyright (c) 2026 Christer Törnkvist.
# SPDX-License-Identifier: GPL-3.0-or-later
"""Persistent spot fixture; never contacts hardware."""
import json,sys,tty
from pathlib import Path
assert '-s' in sys.argv and '-N' not in sys.argv and '-e' not in sys.argv
tty.setraw(sys.stdin.fileno())
def say(text):print(text,flush=True)
def key():assert sys.stdin.read(1)==' '
say('Instrument Type: X-Rite i1 Pro 2\nSerial Number: FIXTURE\nU.V. filter ?: No')
say('Place the instrument on its reflective white reference,\nor hit Esc or Q to abort:')
key();say('Calibration complete\nHit ESC or Q to exit, any other key to take a reading:')
request=json.loads(Path('request.json').read_text())
for reading in request['readings']:
 key();say('Result is XYZ: 10.0 11.0 12.0, D50 Lab: 40.0 -2.0 3.0')
 say('Spectrum from 380.000 to 730.000 nm in 36 steps\n'+', '.join(['12.345']*36)+'\nPeak value 12.345 at 730 nm')
 say('Hit ESC or Q to exit, any other key to take a reading:')
assert sys.stdin.read(1)=='q'
say('Spot read stopped at user request!\nHit Esc or Q to give up, any other key to retry:')
assert sys.stdin.read(1)=='q'
