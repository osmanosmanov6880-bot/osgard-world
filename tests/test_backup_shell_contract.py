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
    def test_successful_snapshot_and_checksum_with_fake_docker(self):
        with tempfile.TemporaryDirectory() as d:
            base=Path(d)
            binary=base/"bin";binary.mkdir()
            docker=binary/"docker"
            docker.write_text("""#!/usr/bin/env python3
import pathlib,sqlite3,shutil,sys
args=sys.argv[1:]
if "exec" in args:
    i=args.index("core-api")
    if args[i+1]=="python":
        path=pathlib.Path(args[-1])
        with sqlite3.connect(path) as db:
            db.execute("CREATE TABLE fixture (id INTEGER PRIMARY KEY)")
            db.execute("INSERT INTO fixture VALUES (1)")
    elif args[i+1]=="rm":
        pathlib.Path(args[-1]).unlink(missing_ok=True)
elif "cp" in args:
    shutil.copyfile(args[-2].removeprefix("core-api:"), args[-1])
else:
    sys.exit(2)
""")
            docker.chmod(0o700)
            dest=base/"backups"
            env=dict(os.environ,PATH=str(binary)+os.pathsep+os.environ.get("PATH",""),
                     OSGARD_CORE_BACKUP_DIR=str(dest))
            r=subprocess.run(["bash",str(SCRIPT)],cwd=ROOT,env=env,capture_output=True,text=True,timeout=20)
            self.assertEqual(r.returncode,0,r.stderr+r.stdout)
            files=list(dest.glob("*.sqlite3"))
            self.assertEqual(len(files),1)
            self.assertEqual(len(list(dest.glob("*.sha256"))),1)
            self.assertEqual(list(dest.glob(".osgard-core-pending-*")),[])
            self.assertEqual(files[0].stat().st_mode & 0o777,0o600)
            check=subprocess.run(["sha256sum","-c",str(files[0])+".sha256"],capture_output=True,text=True)
            self.assertEqual(check.returncode,0,check.stderr)
    def test_atomic_finalization_rejects_collision(self):
        with tempfile.TemporaryDirectory() as d:
            base=Path(d);binary=base/"bin";binary.mkdir()
            docker=binary/"docker"
            docker.write_text("""#!/usr/bin/env python3
import pathlib,sqlite3,shutil,sys
args=sys.argv[1:]
if "exec" in args:
    i=args.index("core-api")
    if args[i+1]=="python":
        with sqlite3.connect(args[-1]) as db:
            db.execute("CREATE TABLE fixture (id INTEGER PRIMARY KEY)")
    elif args[i+1]=="rm":
        pathlib.Path(args[-1]).unlink(missing_ok=True)
elif "cp" in args:
    source=pathlib.Path(args[-2].removeprefix("core-api:"))
    pending=pathlib.Path(args[-1])
    shutil.copyfile(source,pending)
    # Simulate a competing writer occupying the final name immediately before commit.
    target=pending.parent/source.name.replace("osgard-core-backup-","osgard-core-")
    target.write_bytes(b"DO NOT OVERWRITE")
""")
            docker.chmod(0o700)
            dest=base/"backups"
            env=dict(os.environ,PATH=str(binary)+os.pathsep+os.environ.get("PATH",""),
                     OSGARD_CORE_BACKUP_DIR=str(dest))
            r=subprocess.run(["bash",str(SCRIPT)],cwd=ROOT,env=env,
                             capture_output=True,text=True,timeout=20)
            self.assertNotEqual(r.returncode,0)
            self.assertEqual([p.read_bytes() for p in dest.glob("*.sqlite3")],[b"DO NOT OVERWRITE"])
            self.assertEqual(list(dest.glob(".osgard-core-pending-*")),[])
            self.assertEqual(list(dest.glob("*.sha256")),[])
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
