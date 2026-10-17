#!/usr/bin/env python3
"""Create an isolated candidate for the known REMIX inactive scene export.

READ THIS BEFORE USING: this changes the active flags of the three known scene
objects only. It cannot establish that the server bootstrap implements a game.
The candidate must pass real engine rendering/gameplay validation before use.
The original file is never overwritten. Requires UnityPy==1.25.4.
"""
import argparse
import collections
import gzip
import hashlib
import json
from pathlib import Path
import struct
import zlib

import UnityPy
from UnityPy.files import BundleFile
from UnityPy.streams import EndianBinaryReader

ORIGINAL_SHA256 = '38922e28d30ddfee2c2a32fd2e9e0d19dd455af8448ee6472179a7aa33d321b5'
EXPECTED_CLASS_COUNTS = {
    'GameObject': 3, 'Transform': 3, 'Camera': 1, 'RenderSettings': 1,
    'Light': 1, 'LightmapSettings': 1, 'NavMeshSettings': 1, 'MonoBehaviour': 1,
}
EXPECTED_OFFSETS = {1: 726, 2: 774, 3: 822}


def sha(data):
    return hashlib.sha256(data).hexdigest()


def unpack_web(data):
    magic = b'UnityWebData1.0\0'
    assert data.startswith(magic), 'Unexpected Unity data format'
    header = struct.unpack_from('<I', data, len(magic))[0]
    assert len(magic) + 4 < header < 8192, 'Unexpected envelope header'
    pos = len(magic) + 4
    files = {}
    while pos < header:
        offset, length, size = struct.unpack_from('<III', data, pos)
        pos += 12
        assert 0 < size < 300 and offset >= header and offset + length <= len(data)
        name = data[pos:pos + size].decode('utf-8')
        pos += size
        assert name not in files, 'Duplicate envelope entry'
        files[name] = data[offset:offset + length]
    assert pos == header
    return files


def pack_web(files):
    magic = b'UnityWebData1.0\0'
    offset = len(magic) + 4 + sum(12 + len(name.encode()) for name in files)
    header = bytearray(magic + struct.pack('<I', offset))
    for name, content in files.items():
        encoded = name.encode()
        header.extend(struct.pack('<III', offset, len(content), len(encoded)))
        header.extend(encoded)
        offset += len(content)
    return bytes(header) + b''.join(files.values())


def bundle_from(data):
    env = UnityPy.load(data)
    bundles = [file for file in env.files.values() if isinstance(file, BundleFile)]
    assert len(bundles) == 1
    return bundles[0]


def file_bytes(file):
    return file.bytes if isinstance(file, EndianBinaryReader) else file.reader.bytes


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('original', type=Path)
    parser.add_argument('candidate', type=Path)
    parser.add_argument('manifest', type=Path)
    args = parser.parse_args()
    assert UnityPy.__version__ == '1.25.4', 'Use the pinned reader version'
    assert not args.candidate.exists() and not args.manifest.exists(), 'Refusing to overwrite an artifact'
    assert args.original.resolve() not in {args.candidate.resolve(), args.manifest.resolve()}
    original = args.original.read_bytes()
    assert sha(original) == ORIGINAL_SHA256, 'Refusing to patch an unrecognized export'
    files = unpack_web(gzip.decompress(original))
    bundle = bundle_from(files['data.unity3d'])
    scene = bundle.files['level0']
    counts = dict(collections.Counter(obj.type.name for obj in scene.objects.values()))
    assert counts == EXPECTED_CLASS_COUNTS, 'Scene shape changed'
    before_scene = file_bytes(scene)
    after_scene = bytearray(before_scene)
    changes = []
    for object_id, offset in EXPECTED_OFFSETS.items():
        obj = scene.objects[object_id]
        fields = obj.parse_as_dict()
        assert obj.type.name == 'GameObject' and obj.byte_start + obj.byte_size - 1 == offset
        assert fields['m_IsActive'] is False and fields['m_Name'] == '' and fields['m_Tag'] == 0
        assert before_scene[offset] == 0
        after_scene[offset] = 1
        changes.append({'objectId': object_id, 'field': 'm_IsActive', 'before': False, 'after': True, 'level0ByteOffset': offset})
    assert [index for index, (before, after) in enumerate(zip(before_scene, after_scene)) if before != after] == list(EXPECTED_OFFSETS.values())
    original_bundle_files = {name: file_bytes(file) for name, file in bundle.files.items()}
    # Feed exact original serialized streams to the container writer. This
    # avoids reserializing any object, type tree, metadata, or file offset table.
    for name, file in tuple(bundle.files.items()):
        raw = bytes(after_scene) if name == 'level0' else original_bundle_files[name]
        replacement = EndianBinaryReader(raw)
        replacement.flags = file.flags
        bundle.files[name] = replacement
    candidate_bundle = bundle.save(packer='original')
    checked = bundle_from(candidate_bundle)
    assert list(checked.files) == list(original_bundle_files)
    for name, file in checked.files.items():
        expected = bytes(after_scene) if name == 'level0' else original_bundle_files[name]
        assert file_bytes(file) == expected, f'Unexpected decoded changes in {name}'
    for object_id in EXPECTED_OFFSETS:
        assert checked.files['level0'].objects[object_id].parse_as_dict()['m_IsActive'] is True
    result_files = dict(files)
    result_files['data.unity3d'] = candidate_bundle
    candidate = gzip.compress(pack_web(result_files), compresslevel=9, mtime=0)
    roundtrip_files = unpack_web(gzip.decompress(candidate))
    for name, data in files.items():
        if name != 'data.unity3d':
            assert roundtrip_files[name] == data, f'Unexpected envelope change in {name}'
    report = {
        'status': 'experimental_candidate_not_approved_for_publication',
        'purpose': 'Test whether reactivating the inactive camera, light and server bootstrap repairs the empty original scene',
        'reader': f'UnityPy {UnityPy.__version__}', 'zlib': zlib.ZLIB_VERSION,
        'originalGzipSha256': sha(original), 'candidateGzipSha256': sha(candidate),
        'originalSceneSha256': sha(before_scene), 'candidateSceneSha256': sha(after_scene),
        'unityVersion': scene.unity_version,
        'changes': changes, 'decodedSceneBytesChanged': len(changes),
        'unchangedBundleFiles': {name: sha(data) for name, data in original_bundle_files.items() if name != 'level0'},
        'unchangedEnvelopeFiles': {name: sha(data) for name, data in files.items() if name != 'data.unity3d'},
        'sceneClassCounts': counts,
        'requiredValidation': 'Real candidate Nginx delivery, Unity engine startup, meaningful rendered scene, input-driven gameplay response, runtime errors, and no unsupported server startup in WebGL',
        'limitations': 'RemixServerBootstrap may be server-only. No gameplay or deployment success is implied by this file-level repair.',
    }
    args.candidate.parent.mkdir(parents=True, exist_ok=True)
    args.manifest.parent.mkdir(parents=True, exist_ok=True)
    with args.candidate.open('xb') as file:
        file.write(candidate)
    with args.manifest.open('x') as file:
        json.dump(report, file, indent=2)
        file.write('\n')
    print(json.dumps({'candidateSha256': report['candidateGzipSha256'], 'decodedSceneBytesChanged': len(changes), 'status': report['status']}))


if __name__ == '__main__':
    main()
