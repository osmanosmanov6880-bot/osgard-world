#!/usr/bin/env python3
"""OSA CINEMA V64 — verified SQLite snapshot & offline recovery rehearsal.

Runs SQLite's online backup and verifies the resulting standalone database,
including every stored vault BLOB's exact byte count and SHA-256. Does NOT
replace or modify the live database. An unencrypted backup holds sensitive data:
keep it in an access-restricted, independently encrypted storage location.
"""
import argparse
import hashlib
import json
import os
import sqlite3
import sys
from pathlib import Path
from tempfile import TemporaryDirectory

sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'server'))
from core_backup import backup

def sha256_file(path):
    h=hashlib.sha256()
    with open(path,'rb') as f:
        for block in iter(lambda:f.read(1024*1024),b''):
            h.update(block)
    return h.hexdigest()

def inspect(database):
    """Read-only examination of restored SQLite, not a destructive migration."""
    uri=database.resolve().as_uri()+'?mode=ro'
    db=sqlite3.connect(uri,uri=True)
    db.row_factory=sqlite3.Row
    try:
        db.execute('PRAGMA foreign_keys=ON')
        quick=db.execute('PRAGMA integrity_check').fetchone()[0]
        fk_failures=db.execute('PRAGMA foreign_key_check').fetchall()
        verified=0;corrupt=0;total=0
        tables={row[0] for row in db.execute('SELECT name FROM sqlite_master WHERE type="table"')}
        if 'cinema_vault_assets' in tables:
            for a in db.execute('SELECT size_bytes,actual_sha256,content FROM cinema_vault_assets'):
                raw=a['content'];verified+=1
                total+=a['size_bytes']
                if (not isinstance(raw,bytes) or len(raw)!=a['size_bytes'] or
                    hashlib.sha256(raw).hexdigest()!=a['actual_sha256']):
                    corrupt+=1
        return dict(sqliteIntegrity=quick,foreignKeyFailures=len(fk_failures),
                    assetsChecked=verified,assetFailures=corrupt,assetBytes=total,
                    vaultTablePresent='cinema_vault_assets' in tables,
                    passes=quick=='ok' and not fk_failures and not corrupt)
    finally:db.close()

def safe_location(source,target,public_root=None):
    source=source.resolve();target=target.resolve()
    if not source.is_file():raise ValueError('Source SQLite database does not exist.')
    if target.exists():raise ValueError('Destination already exists; a backup may never overwrite.')
    if target==source:raise ValueError('Target must differ from source.')
    if public_root:
        root=public_root.resolve()
        if source.is_relative_to(root) or target.is_relative_to(root):
            raise ValueError('Never place SQLite source or backups in the public web root.')
    return source,target

def rehearse(source,target,public_root=None):
    """Create a true online backup, independently verify it in read-only mode."""
    source,target=safe_location(source,target,public_root)
    # This is a one-way offline result: never replace the live database.
    expected=backup(source,target)
    os.chmod(target,0o600)
    actual=sha256_file(target)
    report=inspect(target)
    report.update(format='OSA_CINEMA_V64_RECOVERY_PROOF_V1',
      backupSha256=actual,backupFileSize=target.stat().st_size,
      checksumMatched=actual==expected,
      verifiedSnapshot=True,restoredIntoLiveProduction=False,
      encryptedBackup=False,productionReady=False,
      legalRightsVerified=False,publicFilmReleaseAuthorized=False)
    report['passes']=report['passes'] and report['checksumMatched']
    return report

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source',type=Path,required=True)
    parser.add_argument('--target',type=Path,required=True)
    parser.add_argument('--public-root',type=Path)
    args=parser.parse_args()
    try:
        result=rehearse(args.source,args.target,args.public_root)
    except (OSError,ValueError,sqlite3.Error) as e:
        # Never print user-supplied file paths or raw bytes in CI logs.
        print(json.dumps(dict(status='FAIL',errorType=type(e).__name__,
                              recoveryVerified=False)))
        return 1
    print(json.dumps(dict(result,status='PASS' if result['passes'] else 'FAIL'),
                     sort_keys=True))
    return 0 if result['passes'] else 1

if __name__=='__main__':sys.exit(main())
