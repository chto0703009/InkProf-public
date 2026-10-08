# Copyright (c) 2026 Christer Törnkvist.
# SPDX-License-Identifier: GPL-3.0-or-later
# InkProf is free software under GNU GPL version 3 or later.
# Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
"""Terminal lifecycle tests with a fake chartread; never use the instrument."""
import json
import os
from pathlib import Path
import pty
import select
import subprocess
import sys
import tempfile
import time
import unittest

ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'bridge'))
from measure_chart import prepare
from test_chartread_bridge import chart


@unittest.skipUnless(os.name=='posix','POSIX terminal required')
class TerminalTests(unittest.TestCase):
    def interact(self, record):
        master,slave=pty.openpty()
        proc=subprocess.Popen([sys.executable,str(ROOT/'bridge/measure_chart.py'),'run',record],
                              stdin=slave,stdout=slave,stderr=slave,start_new_session=True)
        os.close(slave);output=b'';sent=False;closed=False;started=time.monotonic()
        try:
            while time.monotonic()-started<10:
                if select.select([master],[],[],.1)[0]:
                    try:data=os.read(master,65536)
                    except OSError:break
                    if not data:break
                    output+=data
                    if b'FAKE READY' in output and not sent:
                        os.write(master,b'\n');sent=True
                    if b'close this measurement launcher' in output and not closed:
                        os.write(master,b'\n');closed=True
                if proc.poll() is not None:break
            self.assertEqual(proc.wait(timeout=2),0,output.decode(errors='replace'))
            return output.decode(errors='replace')
        finally:
            if proc.poll() is None:proc.kill();proc.wait()
            os.close(master)

    def test_terminal_save_and_resume(self):
        with tempfile.TemporaryDirectory(prefix="InkProf space ' $ ") as tmp:
            folder=Path(tmp);(folder/'chart.json').write_text(json.dumps(chart()))
            fake=folder/'fake chartread'
            fake.write_text('#!'+sys.executable+'\nimport sys,os\nfrom pathlib import Path\n'
                'if "-?" in sys.argv: print("fake version");sys.exit(1)\n'
                'assert os.isatty(0) and os.isatty(1)\n'
                'assert \'"1" "1A" 0 50 100\' in Path("chart.ti2").read_text()\n'
                'print("FAKE READY",flush=True)\ninput()\n'
                'Path("chart.ti3").write_text("synthetic revision 2" if "-r" in sys.argv else "synthetic revision 1")\n')
            fake.chmod(0o700)
            first=prepare(folder,fake,scan_tolerance=1.5,direction="forward")
            # Launcher handles shell metacharacters without executing them.
            import shlex
            cmd=Path(first['launcher']).read_text().split('exec ',1)[1].strip()
            self.assertEqual(shlex.split(cmd)[-1],first['record'])
            self.interact(first['record'])
            one=json.loads(Path(first['record']).read_text())
            self.assertEqual(one['status'],'saved_unvalidated')
            self.assertIn('-B',one['arguments'])
            self.assertEqual(one['arguments'][one['arguments'].index('-T')+1],'1.5')
            self.assertFalse(one['validated'])
            self.assertEqual(Path(one['resultTI3']).read_text(),'synthetic revision 1')
            with self.assertRaisesRegex(ValueError,'TI3 exists'):prepare(folder,fake)
            second=prepare(folder,fake,resume=True,direction="both");self.interact(second['record'])
            two=json.loads(Path(second['record']).read_text())
            self.assertIn('-r',two['arguments'])
            self.assertIn('-b',two['arguments'])
            self.assertNotIn('-B',two['arguments'])
            self.assertEqual(Path(two['previousTI3']).read_text(),'synthetic revision 1')
            self.assertEqual(Path(two['resultTI3']).read_text(),'synthetic revision 2')
            self.assertEqual(Path(one['resultTI3']).read_text(),'synthetic revision 1')
            (folder/'chart.json').write_text(json.dumps(chart())+'\n')
            with self.assertRaisesRegex(ValueError,'same chart'):prepare(folder,fake,resume=True)

    def test_interrupt_releases_child_and_records_status(self):
        with tempfile.TemporaryDirectory() as tmp:
            folder=Path(tmp);(folder/'chart.json').write_text(json.dumps(chart()))
            fake=folder/'fake'
            fake.write_text('#!'+sys.executable+'\nimport sys,time,os\nfrom pathlib import Path\n'
                'if "-?" in sys.argv: sys.exit(0)\n'
                'Path("child.pid").write_text(str(os.getpid()))\n'
                'print("WAITING",flush=True)\ntime.sleep(30)\n')
            fake.chmod(0o700);run=prepare(folder,fake)
            master,slave=pty.openpty()
            proc=subprocess.Popen([sys.executable,str(ROOT/'bridge/measure_chart.py'),'run',run['record']],
                                  stdin=slave,stdout=slave,stderr=slave,start_new_session=True)
            os.close(slave)
            try:
                deadline=time.monotonic()+5
                while not (folder/'child.pid').exists() and time.monotonic()<deadline:time.sleep(.02)
                self.assertTrue((folder/'child.pid').exists())
                pid=int((folder/'child.pid').read_text());proc.terminate()
                while time.monotonic()<deadline:
                    if json.loads(Path(run['record']).read_text())['status']=='interrupted':break
                    time.sleep(.02)
                result=json.loads(Path(run['record']).read_text())
                self.assertEqual(result['status'],'interrupted')
                with self.assertRaises(ProcessLookupError):os.kill(pid,0)
                os.write(master,b'\n')
                self.assertNotEqual(proc.wait(timeout=3),0)
                self.assertNotIn('resultTI3',result)
            finally:
                if proc.poll() is None:proc.kill();proc.wait()
                os.close(master)

    def test_nonterminal_fails_with_record(self):
        with tempfile.TemporaryDirectory() as tmp:
            folder=Path(tmp);(folder/'chart.json').write_text(json.dumps(chart()))
            run=prepare(folder,sys.executable)
            # stdin must not inherit an interactive terminal, or the bridge waits for one.
            p=subprocess.run([sys.executable,str(ROOT/'bridge/measure_chart.py'),'run',run['record']],
                             stdin=subprocess.DEVNULL,capture_output=True,text=True,timeout=5)
            self.assertNotEqual(p.returncode,0)
            result=json.loads(Path(run['record']).read_text())
            self.assertEqual(result['status'],'failed')
            self.assertIn('terminal is required',result['error'])
            self.assertFalse((folder/'chart.ti3').exists())

if __name__=='__main__':unittest.main()
