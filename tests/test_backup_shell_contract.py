"""Safety checks for Core production backup shell entrypoint without Docker."""
import os
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
SCRIPT=ROOT/"scripts/backup-core-production.sh"
class BackupContractTests(unittest.TestCase):
    def test_shell_syntax(self):
        if shutil.which("bash") is None:self.skipTest("bash unavailable")
        r=subprocess.run(["bash","-n",str(SCRIPT)],capture_output=True,text=True)
        self.assertEqual(r.returncode,0,r.stderr)
    def test_failed_docker_does_not_publish_partial_backup(self):
        with tempfile.TemporaryDirectory() as d:
            base=Path(d)
            binary=base/"bin";binary.mkdir()
            docker=binary/"docker"
            docker.write_text("#!/bin/sh\nexit 1\n")
            docker.chmod(0o700)
            dest=base/"backups"
            env=dict(os.environ,PATH=str(binary)+os.pathsep+os.environ.get("PATH",""),
                     OSGARD_CORE_BACKUP_DIR=str(dest))
            r=subprocess.run(["bash",str(SCRIPT)],cwd=ROOT,env=env,capture_output=True,text=True,timeout=15)
            self.assertNotEqual(r.returncode,0)
            self.assertEqual(list(dest.glob("*.sqlite3")),[])
            self.assertEqual(list(dest.glob("*.sha256")),[])
            self.assertEqual(list(dest.glob(".osgard-core-pending-*")),[])
    def test_symlink_backup_directory_refused(self):
        with tempfile.TemporaryDirectory() as d:
            base=Path(d)
            real=base/"real";real.mkdir()
            alias=base/"alias";alias.symlink_to(real,target_is_directory=True)
            env=dict(os.environ,OSGARD_CORE_BACKUP_DIR=str(alias))
            r=subprocess.run(["bash",str(SCRIPT)],cwd=ROOT,env=env,capture_output=True,text=True,timeout=15)
            self.assertNotEqual(r.returncode,0)
            self.assertIn("symlink backup directory",r.stderr)
            self.assertEqual(list(real.iterdir()),[])
if __name__=="__main__":unittest.main()
