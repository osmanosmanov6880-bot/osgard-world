#!/usr/bin/env python3
"""Fail-closed, read-only ZIP release security and integrity gate."""
import argparse
import hashlib
import json
import stat
import sys
import zipfile
from pathlib import Path, PurePosixPath

DEFAULT_MAX_FILES = 20000
DEFAULT_MAX_FILE = 25 * 1024 * 1024
DEFAULT_MAX_TOTAL = 1024 * 1024 * 1024
SECRET_PARTS = {".env", "id_rsa", "id_ed25519", "credentials.json", ".git", ".ssh"}
REQUIRED = {"index.html"}

def validate(archive, max_files=DEFAULT_MAX_FILES, max_file=DEFAULT_MAX_FILE,
             max_total=DEFAULT_MAX_TOTAL):
    archive = Path(archive)
    if archive.is_symlink() or not archive.is_file():
        raise ValueError("archive must be a regular file, not a symlink")
    seen = set()
    roots = set()
    total = 0
    count = 0
    digest = hashlib.sha256()
    with zipfile.ZipFile(archive) as zf:
        infos = zf.infolist()
        if len(infos) > max_files + 1000:
            raise ValueError("archive has too many records")
        for entry in infos:
            name = entry.filename
            if not name or "\\" in name or name.startswith("/") or "\x00" in name:
                raise ValueError("unsafe archive filename: " + repr(name))
            path = PurePosixPath(name)
            parts = path.parts
            if ".." in parts or "." in parts or ":" in parts[0]:
                raise ValueError("unsafe archive path: " + repr(name))
            if any(part.lower() in SECRET_PARTS or part.lower().startswith(".env.")
                   for part in parts):
                raise ValueError("secret-looking path prohibited: " + repr(name))
            canonical = str(path).rstrip("/")
            folded = canonical.casefold()
            if folded in seen:
                raise ValueError("duplicate or case-colliding path: " + repr(name))
            seen.add(folded)
            unix_type = (entry.external_attr >> 16) & 0xF000
            if unix_type not in (0, stat.S_IFREG, stat.S_IFDIR):
                raise ValueError("links and special files prohibited: " + repr(name))
            if entry.flag_bits & 1:
                raise ValueError("encrypted entries prohibited")
            if entry.is_dir():
                continue
            if unix_type == stat.S_IFDIR:
                raise ValueError("directory entry has file content")
            count += 1
            if count > max_files:
                raise ValueError("too many files")
            if entry.file_size <= 0 or entry.file_size > max_file:
                raise ValueError("empty or oversized file: " + repr(name))
            total += entry.file_size
            if total > max_total:
                raise ValueError("archive exceeds total uncompressed limit")
            if entry.compress_size == 0 or entry.file_size > max(1024, entry.compress_size) * 10000:
                raise ValueError("suspicious compression ratio: " + repr(name))
            # Streaming extraction into memory bounded chunks; CRC is checked by zipfile on EOF.
            read_bytes = 0
            with zf.open(entry) as stream:
                while True:
                    chunk = stream.read(1024 * 1024)
                    if not chunk:
                        break
                    read_bytes += len(chunk)
                    if read_bytes > entry.file_size:
                        raise ValueError("entry expanded beyond declared size")
                    if name == "index.html":
                        digest.update(chunk)
            if read_bytes != entry.file_size:
                raise ValueError("entry size mismatch")
            roots.add(canonical)
    missing = REQUIRED - roots
    if missing:
        raise ValueError("missing root-level entrypoint: " + ", ".join(sorted(missing)))
    return {"status": "passed", "files": count, "uncompressed_bytes": total,
            "root_entrypoint_sha256": digest.hexdigest(),
            "archive_sha256": hash_file(archive),
            "no_publish_performed": True}

def hash_file(path):
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()

def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("archive", type=Path)
    p.add_argument("--max-files", type=int, default=DEFAULT_MAX_FILES)
    p.add_argument("--max-file-bytes", type=int, default=DEFAULT_MAX_FILE)
    p.add_argument("--max-total-bytes", type=int, default=DEFAULT_MAX_TOTAL)
    args = p.parse_args()
    if min(args.max_files, args.max_file_bytes, args.max_total_bytes) <= 0:
        p.error("limits must be positive")
    try:
        result = validate(args.archive, args.max_files, args.max_file_bytes, args.max_total_bytes)
    except (OSError, ValueError, zipfile.BadZipFile, RuntimeError, EOFError) as e:
        print("BLOCK RELEASE: " + str(e), file=sys.stderr)
        return 2
    print(json.dumps(result, ensure_ascii=False, indent=2))
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
