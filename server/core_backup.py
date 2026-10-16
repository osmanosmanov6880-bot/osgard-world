#!/usr/bin/env python3
"""Online consistent SQLite backup, offline restore into a new path only."""
from pathlib import Path
from contextlib import closing
import argparse
import hashlib
import os
import sqlite3

def backup(source,destination):
    source=Path(source).resolve();destination=Path(destination).resolve()
    if not source.is_file():raise ValueError('Source database is missing.')
    if destination.exists():raise ValueError('Destination already exists; choose a new path.')
    destination.parent.mkdir(parents=True,exist_ok=True)
    # Reserve a private file before SQLite opens it.
    fd=os.open(destination,os.O_CREAT|os.O_EXCL|os.O_WRONLY,0o600);os.close(fd)
    try:
        with closing(sqlite3.connect(source.as_uri()+'?mode=ro',uri=True)) as src,closing(sqlite3.connect(destination)) as dst:
            src.backup(dst)
            if dst.execute('PRAGMA integrity_check').fetchone()[0]!='ok':raise ValueError('Integrity check failed.')
            if dst.execute('PRAGMA user_version').fetchone()[0]!=1:raise ValueError('Unsupported Core schema.')
        return hashlib.sha256(destination.read_bytes()).hexdigest()
    except BaseException:
        destination.unlink(missing_ok=True);raise

def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('mode',choices=['backup','restore']);p.add_argument('source',type=Path);p.add_argument('destination',type=Path);args=p.parse_args()
    if args.mode=='restore':print('Restore target must be new. Stop the Core server and restart it with --database pointing to the restored file.')
    checksum=backup(args.source,args.destination);print('Core database copy validated. SHA-256:',checksum)
if __name__=='__main__':main()
