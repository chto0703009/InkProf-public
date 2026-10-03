# Copyright (c) 2026 Christer Törnkvist.
# SPDX-License-Identifier: GPL-3.0-or-later
# InkProf is free software under GNU GPL version 3 or later.
# Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
"""Transport tests use a fake child, never a measuring instrument."""
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'bridge'))
from chartread_bridge import chart_to_ti2


def chart():
    return dict(schemaVersion=1, documentType='inkprof.measurement-chart', colorSpace='RGB', patchCount=1,
                patches=[dict(sampleId='1', sampleLoc='1A', rgbPercent=[0, 50, 100])],
                exchangeTables=[dict(signature='CTI2', fields=['SAMPLE_ID', 'SAMPLE_LOC','RGB_R','RGB_G','RGB_B'],
                metadata=[dict(tokens=['COLOR_REP','RGB'])], rows=[dict(values=['1','1A','0','0','0'])])])


@unittest.skipUnless(os.name == 'posix', 'PTY adapter supports POSIX')
class BridgeTests(unittest.TestCase):
    def test_numeric_tokens_are_unquoted(self):
        c = chart()
        c['exchangeTables'][0]['fields'] += ['XYZ_X', 'XYZ_Y', 'XYZ_Z']
        c['exchangeTables'][0]['rows'][0]['values'] += ['1.2e-3', '0.0', '100']
        raw = chart_to_ti2(c)
        row = raw.split('BEGIN_DATA\n')[1].splitlines()[0]
        self.assertEqual(row, '\"1\" \"1A\" 0 50 100 1.2e-3 0.0 100')

    def test_rgb_guard(self):
        c = chart(); c['patches'][0]['rgbPercent'] = [0, 0, 0, 0]
        with self.assertRaises(ValueError): chart_to_ti2(c)

    def test_startup_reconnection_is_bounded_and_not_used_after_calibration(self):
        for failures, prefix, expected in [(2, '', 3), (9, '', 3),
                                           (9, 'Place the instrument on its reflective white reference', 1)]:
            with self.subTest(failures=failures, prefix=prefix), tempfile.TemporaryDirectory() as directory:
                folder = Path(directory)
                (folder/'chart.json').write_text(json.dumps(chart()))
                fake = folder/'fake-chartread'
                fake.write_text('#!'+sys.executable+'\nimport sys\nfrom pathlib import Path\n'
                    'if "-?" in sys.argv: sys.exit(0)\n'
                    'p=Path("attempts"); n=int(p.read_text())+1 if p.exists() else 1; p.write_text(str(n))\n'
                    f'if n <= {failures}:\n'
                    f' print({prefix!r}, flush=True)\n'
                    ' print("Initialising instrument failed with message Communications failure", flush=True)\n'
                    ' sys.exit(1)\n'
                    'Path("chart.ti3").write_text("synthetic test only")\n')
                fake.chmod(0o755)
                proc = subprocess.Popen([sys.executable, str(ROOT/'bridge/chartread_bridge.py'),
                                         str(folder), str(fake)], stdin=subprocess.PIPE,
                                        stdout=subprocess.PIPE, text=True)
                try:
                    # Keep controller input open without sending calibration/measurement keys.
                    events = [json.loads(line) for line in proc.stdout]
                    code = proc.wait(timeout=10)
                    self.assertEqual(int((folder/'attempts').read_text()), expected)
                    self.assertEqual(code, 0 if failures == 2 else 1)
                    self.assertEqual(len(list(folder.glob('transcript-*.txt'))), expected)
                    self.assertEqual(len(list(folder.glob('run-*.json'))), expected)
                    self.assertEqual(events[-1]['event'], 'exited')
                finally:
                    if proc.poll() is None: proc.kill(); proc.wait()
                    proc.stdin.close(); proc.stdout.close()

    def test_interaction_and_resume_guard(self):
        self.check_interaction(False)

    def test_interaction_survives_temporary_input_and_output_unavailability(self):
        self.check_interaction(True)

    def check_interaction(self, transient):
        with tempfile.TemporaryDirectory(prefix='InkProf bridge ') as directory:
            folder = Path(directory)
            (folder/'chart.json').write_text(json.dumps(chart()))
            fake = folder/'fake chartread'
            fake.write_text('#!'+sys.executable+'\nimport sys\nfrom pathlib import Path\n'
                            'if "-?" in sys.argv: print("Fake chartread test version");sys.exit(1)\n'
                            'print("TEST prompt",flush=True)\ninput()\nPath("chart.ti3").write_text("synthetic test only")\n')
            fake.chmod(0o755)
            script = ROOT/'bridge/chartread_bridge.py'
            if transient:
                wrapper = folder/'inject.py'
                wrapper.write_text(
                    'import sys, runpy, errno\n'
                    f'sys.path.insert(0, {str(ROOT/"bridge")!r})\n'
                    'import pty_transport\n'
                    'original=pty_transport.read_ready; seen=set()\n'
                    'def injected(fd, *, pty_output=False):\n'
                    ' if fd not in seen:\n'
                    '  seen.add(fd); real=pty_transport.os.read\n'
                    '  def unavailable(*args): raise BlockingIOError(errno.EAGAIN, "temporary")\n'
                    '  pty_transport.os.read=unavailable\n'
                    '  try: return original(fd, pty_output=pty_output)\n'
                    '  finally: pty_transport.os.read=real\n'
                    ' return original(fd, pty_output=pty_output)\n'
                    'pty_transport.read_ready=injected\n'
                    f'runpy.run_path({str(script)!r}, run_name="__main__")\n'
                    'assert len(seen)==2\n')
                script = wrapper
            proc = subprocess.Popen([sys.executable, str(script), str(folder), str(fake), '--scan-tolerance', '1', '--direction', 'forward'],
                                    stdin=subprocess.PIPE, stdout=subprocess.PIPE, text=True)
            try:
                events=[]
                while True:
                    event=json.loads(proc.stdout.readline());events.append(event)
                    if event['event']=='output' and 'TEST prompt' in event['text']:
                        proc.stdin.write(json.dumps(dict(command='key',text='\r'))+'\n');proc.stdin.flush()
                    if event['event']=='exited': break
                self.assertEqual(proc.wait(timeout=5),0)
                self.assertFalse(events[-1]['validated'])
                started = next(e for e in events if e['event'] == 'started')
                self.assertEqual(started['arguments'][1:], ['-v', '-T', '1', '-B', 'chart'])
                self.assertTrue((folder/'chart.ti2').exists())
                # A rerun cannot overwrite a saved result without explicit resume.
                failed=subprocess.run([sys.executable,str(ROOT/'bridge/chartread_bridge.py'),str(folder),str(fake)],capture_output=True,text=True,timeout=5)
                self.assertNotEqual(failed.returncode,0)
                self.assertIn('use resume',failed.stdout)
            finally:
                if proc.poll() is None: proc.kill();proc.wait()
                proc.stdin.close();proc.stdout.close()

if __name__=='__main__': unittest.main()
