"""OSA CINEMA V64 — actual stored-byte integrity and bounded owner storage.

A local integrity check proves ONLY that bytes in the current SQLite database
match the SHA-256 recorded when the asset was uploaded. It does not prove the
media source, rights, absence of malware, immutable custody, or film completion.
"""
import hashlib
import re
from core_model import require, now
import core_cinema

MAX_OWNER_BYTES=64*1024*1024
ID=re.compile(r'[a-f0-9]{32}\Z')

def owner_usage(db,owner_id):
    """Includes files uploaded by editors into every workspace of the owner."""
    row=db.execute('''
        SELECT COALESCE(SUM(a.size_bytes),0) AS total,COUNT(*) AS assets,
               COUNT(DISTINCT a.space_id) AS populated
        FROM cinema_vault_assets a
        JOIN cinema_spaces s ON s.id=a.space_id
        WHERE s.owner_id=?''',(owner_id,)).fetchone()
    return dict(usedBytes=int(row['total']),assets=int(row['assets']),
                spacesWithFiles=int(row['populated']),limitBytes=MAX_OWNER_BYTES,
                remainingBytes=max(0,MAX_OWNER_BYTES-int(row['total'])))

def owner_storage(db,actor):
    """Account-scoped quota overview — never exposes another owner's data."""
    usage=owner_usage(db,actor)
    spaces=db.execute('SELECT COUNT(*) FROM cinema_spaces WHERE owner_id=?',(actor,)).fetchone()[0]
    return dict(ownerId=actor,ownedSpaces=spaces,**usage,
                encryptedAtRest=False,serverAntivirus=False,
                externallyAttested=False,commercialSla=False,
                productionReady=False,releaseAuthorized=False,publicVideoUrl=None)

def verify(db,space_id,actor):
    """Owner-only, read-only, recomputes SHA256 from real BLOB bytes."""
    require(isinstance(space_id,str) and ID.fullmatch(space_id),
            'Кинопространство не найдено.','not_found',404)
    space=core_cinema.access(db,space_id,actor,owner=True)
    rows=db.execute('''SELECT id,name,mime,size_bytes,actual_sha256,content
          FROM cinema_vault_assets WHERE space_id=? ORDER BY rowid DESC''',
          (space_id,)).fetchall()
    assets=[]
    for row in rows:
        raw=row['content']
        is_bytes=isinstance(raw,(bytes,bytearray,memoryview))
        actual=hashlib.sha256(bytes(raw)).hexdigest() if is_bytes else None
        good=(is_bytes and len(raw)==row['size_bytes'] and
              actual==row['actual_sha256'])
        assets.append(dict(assetId=row['id'],name=row['name'],
            bytes=row['size_bytes'],expectedSha256=row['actual_sha256'],
            computedSha256=actual,match=bool(good),mediaType=row['mime']))
    failed=sum(not a['match'] for a in assets)
    return dict(spaceId=space_id,spaceVersion=space['version'],
        checkedAt=now(),status='PASS' if failed==0 else 'FAIL',
        filesChecked=len(assets),filesFailed=failed,storedByteIntegrity=failed==0,
        assets=assets,ownerQuota=owner_usage(db,space['owner_id']),
        scope='Stored SQLite bytes only; not source authenticity, external certification or AV.',
        encryptionAtRest=False,serverAntivirus=False,
        legalRightsClearance=False,professionalCustodyVerification=False,
        publicFilmReleaseAuthorized=False,publicVideoUrl=None,
        productionReady=False)
