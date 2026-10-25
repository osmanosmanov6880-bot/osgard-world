#!/usr/bin/env python3
"""Package verified OSGARD Godot artifacts without changing production.

Source-bound packaging tool. Rejects mismatched or missing manifests, path
traversal, altered resource bytes, incomplete gameplay evidence, and fake
binary extensions. Does NOT certify AAA visual quality or real device FPS.
"""
import argparse
import hashlib
import json
import struct
import zipfile
from pathlib import Path, PurePosixPath

DATE = (2026, 10, 26, 0, 0, 0)
SHA = lambda b: hashlib.sha256(b).hexdigest()


def load_zip(path):
    files = {}
    with zipfile.ZipFile(path) as z:
        failed = z.testzip()
        if failed is not None:
            raise ValueError(f"CRC failure: {path}: {failed}")
        for item in z.infolist():
            if item.is_dir():
                continue
            name = item.filename
            p = PurePosixPath(name)
            if name.startswith('/') or len(p.parts) < 1 or '..' in p.parts or '\\' in name:
                raise ValueError(f"Unsafe archive path: {name}")
            if name in files:
                raise ValueError(f"Duplicate ZIP entry: {name}")
            files[name] = z.read(item)
    return files


def manifest_bytes(files, name):
    if name not in files:
        raise ValueError(f"Evidence file {name} missing")
    return json.loads(files[name])


def check_entries(files, manifest):
    entries = manifest.get('files')
    if not isinstance(entries, list) or len(entries) < 2:
        raise ValueError('Manifest missing source-bound file entries')
    for item in entries:
        name = item['name']
        if name not in files:
            raise ValueError(f"Manifest member not present: {name}")
        data = files[name]
        if len(data) != item['bytes'] or SHA(data) != item['sha256']:
            raise ValueError(f"Original byte digest mismatch: {name}")


def validate_web(files, source):
    manifest = manifest_bytes(files, 'evidence.json')
    if manifest.get('source_commit') != source or manifest.get('godot_release') != '4.4.1':
        raise ValueError('WebGL artifact SHA or engine version mismatch')
    check_entries(files, manifest)
    for name in ('index.html', 'index.js', 'index.wasm', 'index.pck'):
        if name not in files:
            raise ValueError(f"Not an actual Godot WebGL build: {name}")
    if set(files) != ({x['name'] for x in manifest['files']} | {'evidence.json'}):
        raise ValueError('Unsigned extra WebGL archive file')
    if files['index.wasm'][:4] != b'\0asm' or files['index.pck'][:4] != b'GDPC':
        raise ValueError('Invalid real WASM or PCK magic')
    return manifest


def validate_windows(files, source):
    manifest = manifest_bytes(files, 'windows-build.json')
    if manifest.get('source_commit') != source or manifest.get('godot_release') != '4.4.1':
        raise ValueError('Windows artifact SHA or engine mismatch')
    if manifest.get('architecture') != 'x86_64' or manifest.get('software_export') != 'PASS':
        raise ValueError('Windows export is not marked as native x86_64 PASS')
    check_entries(files, manifest)
    if set(files) != ({x['name'] for x in manifest['files']} | {'windows-build.json'}):
        raise ValueError('Unsigned extra Windows archive file')
    exe = files.get('OSGARD_FIELD_LAB_W33.exe', b'')
    pck = files.get('OSGARD_FIELD_LAB_W33.pck', b'')
    if exe[:2] != b'MZ' or len(exe) < 3_000_000 or pck[:4] != b'GDPC':
        raise ValueError('Invalid real Windows EXE/PCK content')
    pe_offset = struct.unpack_from('<I', exe, 60)[0]
    if exe[pe_offset:pe_offset+4] != b'PE\0\0':
        raise ValueError('Windows file has no PE signature')
    return manifest


def validate_gameplay(files, source):
    manifest = manifest_bytes(files, 'gameplay-evidence.json')
    if manifest.get('source_sha') != source or manifest.get('status') != 'PASS':
        raise ValueError('No successful source-bound gameplay evidence')
    if manifest.get('gameplay_verified_by_real_canvas_events') is not True:
        raise ValueError('Game inputs did not pass actual browser tests')
    devices = manifest.get('devices', [])
    if not any(d.get('result') == 'PASS' and d.get('missions') == [0,1,2,3,4,5] for d in devices):
        raise ValueError('Not all six original browser missions passed')
    return manifest


def validate_art(files, source):
    manifest = manifest_bytes(files, 'visual-evidence.json')
    if manifest.get('source_sha') != source or manifest.get('status') != 'PASS':
        raise ValueError('Original art evidence missing or FAIL')
    if manifest.get('real_godot_export') is not True or manifest.get('not_concept_art') is not True:
        raise ValueError('Art source is not a real Godot native render')
    if len(manifest.get('frames', [])) < 5:
        raise ValueError('Less than five original art screenshots')
    for entry in manifest['frames']:
        data = files.get(entry['image'])
        if not data or data[:8] != b'\x89PNG\r\n\x1a\n' or SHA(data) != entry['sha256']:
            raise ValueError(f"Modified/missing Godot original image: {entry['image']}")
    if 'ORIGINAL_W39_OBSIDIAN_CONTACT_SHEET.png' not in files:
        raise ValueError('Visual review mosaic is missing')
    return manifest


def validate_windows_boot(files, source):
    proof = manifest_bytes(files, 'windows-boot-verdict.json')
    if proof.get('source_commit') != source:
        raise ValueError('Actual Windows runner evidence belongs to another commit')
    if proof.get('actual_windows_runner_exe_started') is not True or proof.get('exit_code') != 0:
        raise ValueError('Original Windows EXE did not boot and exit cleanly')
    if proof.get('desktop_render_verified') is not False or proof.get('physical_user_device_verified') is not False:
        raise ValueError('Windows runner proof must not claim real device rendering')
    if not all(n in files for n in ('w34-windows-stdout.txt', 'w34-windows-stderr.txt')):
        raise ValueError('Original Windows console evidence missing')
    if set(files) != {'windows-boot-verdict.json','w34-windows-stdout.txt','w34-windows-stderr.txt'}:
        raise ValueError('Unexpected file in Windows boot proof')
    return proof


def emit_file(z, name, data):
    info = zipfile.ZipInfo(name, DATE)
    info.compress_type = zipfile.ZIP_DEFLATED
    info.external_attr = (0o100644 << 16)
    z.writestr(info, data, compresslevel=7)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--web', required=True, type=Path)
    parser.add_argument('--windows', required=True, type=Path)
    parser.add_argument('--gameplay', required=True, type=Path)
    parser.add_argument('--art', type=Path)
    parser.add_argument('--windows-boot', type=Path)
    parser.add_argument('--sha', required=True)
    parser.add_argument('--out', required=True, type=Path)
    args = parser.parse_args()
    source = args.sha
    if len(source) != 40 or any(c not in '0123456789abcdef' for c in source):
        raise ValueError('A full, exact 40-character source Git SHA is mandatory')
    web = load_zip(args.web)
    windows = load_zip(args.windows)
    gameplay = load_zip(args.gameplay)
    validate_web(web, source)
    validate_windows(windows, source)
    validate_gameplay(gameplay, source)
    art = load_zip(args.art) if args.art else None
    if art:
        validate_art(art, source)
    boot = load_zip(args.windows_boot) if args.windows_boot else None
    if boot:
        validate_windows_boot(boot, source)
    note = (
        'OSGARD OBSIDIAN / ORIGINAL GODOT 4.4.1 CANDIDATE\n'
        f'EXACT SOURCE SHA: {source}\n\n'
        'WINDOWS 10/11 x64: unzip everything, open windows/OSGARD_FIELD_LAB_W33.exe\n'
        'and keep windows/OSGARD_FIELD_LAB_W33.pck next to the EXE.\n'
        'This is a test candidate. Avoid running as Administrator.\n\n'
        'Web: open web/index.html through an HTTP server, not file://.\n'
        'Run: cd web && python -m http.server 8765 --bind 127.0.0.1\n'
        'Then visit: http://127.0.0.1:8765/\n\n'
        'Graphics: HERO/ECO. All 6 missions passed real browser control QA\n'
        'for the exact SHA above. Physical phone, GPU and AAA quality unverified.\n'
        'This archive does not publish or modify the live osgard.world site.\n'
    )
    payload = {}
    for filename, data in web.items():
        payload['web/'+filename] = data
    for filename, data in windows.items():
        payload['windows/'+filename] = data
    for filename, data in gameplay.items():
        payload['qa/gameplay/'+filename] = data
    if art:
        for filename,data in art.items():
            payload['qa/real_art/'+filename] = data
    if boot:
        for filename, data in boot.items():
            payload['qa/windows_boot/'+filename] = data
    payload['README_START_HERE.txt'] = note.encode('utf-8')
    file_manifest = {'source_commit':source,'godot':'4.4.1','candidate_only':True,
                     'production_modified':False,'physical_device_certified':False,
                     'AAA_graphics_certified':False,'browser_6_cases_verified':True,
                     'windows_executable_built':True,'windows_os_boot_verified':bool(boot),
                     'original_visual_evidence_included':bool(art),
                     'files':[{'name':k,'bytes':len(v),'sha256':SHA(v)} for k,v in sorted(payload.items())]}
    payload['CANDIDATE_MANIFEST.json'] = (json.dumps(file_manifest,indent=2,sort_keys=True)+'\n').encode('utf-8')
    args.out.parent.mkdir(parents=True,exist_ok=True)
    with zipfile.ZipFile(args.out, 'w', allowZip64=True) as z:
        for name in sorted(payload):
            emit_file(z,name,payload[name])
    # Independently reread the ZIP from disk and audit all member digests.
    built = load_zip(args.out)
    for record in file_manifest['files']:
        blob=built.get(record['name'])
        if blob is None or len(blob)!=record['bytes'] or SHA(blob)!=record['sha256']:
            raise ValueError('Packaged candidate fails independent re-verification')
    result={'result':'PASS', 'source_sha':source,'files':len(built),
            'zip':str(args.out),'size_bytes':args.out.stat().st_size,
            'zip_sha256':SHA(args.out.read_bytes()),'has_art':bool(art),
            'windows_os_boot_verified':bool(boot)}
    print(json.dumps(result,indent=2))

if __name__ == '__main__':
    main()