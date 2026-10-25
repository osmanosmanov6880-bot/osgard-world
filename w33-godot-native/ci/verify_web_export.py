#!/usr/bin/env python3
"""Fail-closed software-only byte checks of real Godot Web export files.

This utility does not export Godot and must NEVER claim that mocked inputs
are real playable WebGL. It runs only after the real Godot CLI export job.
"""
import argparse
import hashlib
import json
import os
import stat
import sys
from pathlib import Path

REQUIRED = {
    'index.html': (220, None),
    'index.js': (1024, None),
    'index.wasm': (100000, b'\x00asm'),
    'index.pck': (4096, b'GDPC'),
}


def fail_if(condition, message):
    if condition:
        raise ValueError(message)


def verify(directory: Path, *, sha: str) -> dict:
    directory = directory.resolve(strict=True)
    fail_if(not directory.is_dir(), 'Web artifact path must be a directory')
    fail_if(len(sha) != 40 or any(x not in '0123456789abcdef' for x in sha),
            'Godot commit must be a pinned 40-character lowercase hex SHA')
    seen = set()
    files = []
    for path in sorted(directory.rglob('*')):
        rel = path.relative_to(directory).as_posix()
        fail_if(path.is_symlink(), 'Symlinks cannot enter immutable release: ' + rel)
        fail_if(path.is_file() and not str(path.resolve()).startswith(str(directory) + os.sep),
                'Unsafe path escape: ' + rel)
        if path.is_dir():
            continue
        fail_if(not path.is_file(), 'Non-regular file forbidden: ' + rel)
        fail_if(rel in seen, 'Duplicate exported path: ' + rel)
        seen.add(rel)
        contents = path.read_bytes()
        fail_if(len(contents) == 0, 'Empty Godot export file: ' + rel)
        fail_if(len(contents) > 300 * 1024 * 1024, 'Unexpected huge WebGL file: ' + rel)
        files.append({'name': rel, 'bytes': len(contents),
                      'sha256': hashlib.sha256(contents).hexdigest()})
    for name, (threshold, magic) in REQUIRED.items():
        target = directory / name
        fail_if(not target.is_file() or target.is_symlink(), 'Godot WebGL build missing ' + name)
        data = target.read_bytes()
        fail_if(len(data) < threshold, name + ' is too small for a real Godot export')
        if magic is not None:
            fail_if(not data.startswith(magic), 'Invalid ' + name + ' binary header')
    html = (directory / 'index.html').read_text('utf-8')
    fail_if('<canvas' not in html.lower(), 'Godot HTML must mount the real canvas')
    fail_if('index.js' not in html, 'Godot HTML must reference its actual runtime script')
    manifest = {'schema': 'OSGARD_W33_GODOT_WEB_BYTES_V1',
                'source_commit': sha, 'godot_release': '4.4.1',
                'software_only': True, 'physical_phone_verified': False,
                'native_run_verified_by_this_tool': False,
                'browser_gameplay_verified_by_this_tool': False,
                'files': files}
    return manifest


def main(argv=None):
    parser = argparse.ArgumentParser(description='Inspect exact real Godot WebGL files, do not certify device performance')
    parser.add_argument('directory', type=Path)
    parser.add_argument('--sha', required=True)
    parser.add_argument('--output', type=Path)
    args = parser.parse_args(argv)
    manifest = verify(args.directory, sha=args.sha)
    text = json.dumps(manifest, indent=2, ensure_ascii=False) + '\n'
    if args.output:
        args.output.write_text(text)
    else:
        sys.stdout.write(text)
    print('SOFTWARE EXPORT BYTES VERIFIED — not native/mobile/AAA certification', file=sys.stderr)

if __name__ == '__main__':
    main()
