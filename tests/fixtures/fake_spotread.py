#!/usr/bin/env python3
# Copyright (c) 2026 Christer Törnkvist.
# SPDX-License-Identifier: GPL-3.0-or-later
# InkProf is free software under GNU GPL version 3 or later.
# Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
"""Deterministic PTY fixture: no instrument access."""
import sys,tty
assert '-s' in sys.argv and '-e' not in sys.argv and '-N' not in sys.argv
tty.setraw(sys.stdin.fileno())
def say(s): print(s,flush=True)
def key():
 c=sys.stdin.read(1)
 if c=='q':sys.exit(0)
 assert c==' ',repr(c)
say('Instrument Type: X-Rite i1 Pro 2\nSerial Number: FIXTURE\nU.V. filter ?: No')
say('Place the instrument on its reflective white reference S/N FIXTURE,\nand then hit any key to continue,\nor hit Esc or Q to abort:')
key();say("Calibration failed with 'Measurement misread'\nHit any key to retry, or Esc or Q to abort:")
key();say('Calibration complete\nHit ESC or Q to exit, any other key to take a reading:')
key();say('Result is XYZ: 10.0 11.0 12.0, D50 Lab: 40.0 -2.0 3.0')
say('Spectrum from 380.000 to 730.000 nm in 36 steps\n'+', '.join(['12.345']*36)+'\nPeak value 12.345 at (aprox.) 730.0 nm')
say('Hit ESC or Q to exit, any other key to take a reading:')
# Real i1Pro 2 can ask for a second quit after a valid reading.
assert sys.stdin.read(1)=='q'
say('Spot read stopped at user request!\nHit Esc or Q to give up, any other key to retry:')
assert sys.stdin.read(1)=='q'
