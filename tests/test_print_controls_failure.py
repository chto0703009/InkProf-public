# Copyright (c) 2026 Christer Törnkvist.
# SPDX-License-Identifier: GPL-3.0-or-later
# Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
"""Exercise an instrument startup failure without accessing a USB device."""
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
sys.path.insert(0, str(Path(__file__).resolve().parents[1]/'bridge'))
from print_controls_bridge import ControlProcessError
ROOT = Path(__file__).resolve().parents[1]


class ControlFailureTests(unittest.TestCase):
    def test_communication_failure_keeps_cause_and_saved_count(self):
        error = ControlProcessError("Instrument initialisation failed with 'Communications failure'!", Path('/tmp/fixture'), 255, 0, 3)
        self.assertIn('USB communication', str(error))
        self.assertIn('0/3', str(error))
        self.assertTrue(error.communication_failure)
        self.assertIn('Communications failure', error.diagnostic)
        partial = ControlProcessError('Communications failure', Path('/tmp/fixture'), 255, 2, 3)
        self.assertIn('2/3', str(partial))
        self.assertNotIn('initialisation', str(partial))

    def test_bridge_reports_real_failure_and_retains_transcript(self):
        with tempfile.TemporaryDirectory() as directory:
            folder = Path(directory)
            (folder/'request.json').write_text(json.dumps(dict(documentType='inkprof.print-control-test', calibrationStandard='XRGA', readings=[dict(page=1, colour=c) for c in 'RGB'])))
            fake = folder/'fake-spotread'
            fake.write_text("#!/bin/sh\nprintf \"Instrument initialisation failed with 'Communications failure'!\\n\"\nexit 255\n")
            fake.chmod(0o755)
            process = subprocess.Popen([sys.executable, str(ROOT/'bridge/print_controls_bridge.py'), str(folder), str(fake)], stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
            try:
                events = [json.loads(line) for line in process.stdout]
                process.wait(timeout=10)
                failure = next(e for e in events if e['event']=='error')
                self.assertEqual(process.returncode, 1)
                self.assertEqual(failure['exitCode'], 255)
                self.assertEqual(failure['recorded'], 0)
                self.assertTrue(failure['communicationFailure'])
                self.assertIn('Communications failure', Path(failure['transcript']).read_text())
                self.assertEqual(json.loads((folder/'run.json').read_text())['recorded'], 0)
                self.assertFalse(list(folder.glob('reading-*.json')))
            finally:
                if process.poll() is None: process.kill(); process.wait()
                for stream in [process.stdin, process.stdout, process.stderr]: stream.close()


if __name__=='__main__': unittest.main()
