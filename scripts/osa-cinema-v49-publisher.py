#!/usr/bin/env python3
"""OSA CINEMA V49: fail-closed, exact-byte offline staging and atomic activation.

No network calls, no GitHub writes, no automatic public publication. The active
symlink is switched ONLY with the explicit 'activate' command. Media lives in a
separate host-mounted directory that is never swapped by frontend deploys.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import stat
import sys
import tempfile

RELEASE_RE = re.compile(r"osa-v[0-9]+-[0-9a-z][0-9a-z-]{2,48}")
HEX = re.compile(r"[0-9a-f]{64}")
MEDIA = {
    "osa-v48-directors-ru": "masters/osa-v48-directors-ru.mp4",
    "osa-v48-directors-en": "masters/osa-v48-directors-en.mp4",
    "osa-v48-trailer-ru": "masters/osa-v48-trailer-ru.mp4",
    "osa-v48-trailer-en": "masters/osa-v48-trailer-en.mp4",
    "osa-v48-directors-ru-captions": "captions/osa-v48-directors-ru.vtt",
    "osa-v48-directors-en-captions": "captions/osa-v48-directors-en.vtt",
    "osa-v48-trailer-ru-captions": "captions/osa-v48-trailer-ru.vtt",
    "osa-v48-trailer-en-captions": "captions/osa-v48-trailer-en.vtt",
}
EXTRA = ("index.html", "assets/osa-premiere-poster.jpg", "manifest.json")
# These files execute/render on the trusted OSGARD origin: their self-authored
# SHA256SUMS.txt is insufficient. Pin exact owner-reviewed V48.1 bytes in code.
EXTRA_PIN = {
    "index.html": "e3ac23a5b5f0fc0643b019bb4cc4f89bc175876ef32f844bd306e3fbef486f29",
    "assets/osa-premiere-poster.jpg": "ba1a19a4bbda35a1b6bcee45326775ea4bf990607ff8aec3bdcf618bf1baf77d",
    "manifest.json": "aa81eae3d71fb5e8d76df983a09fae3bbce7499867404022eabaff3e06ca67a5",
}
ALL_FILES = set(MEDIA.values()) | set(EXTRA)


class GateError(RuntimeError):
    pass


def deny(message):
    raise GateError(message)


def sha256_file(path):
    h = hashlib.sha256()
    with path.open("rb") as file:
        for buf in iter(lambda: file.read(1024 * 1024), b""):
            h.update(buf)
    return h.hexdigest()


def real_dir(path):
    path = Path(path).absolute()
    for element in (path, *path.parents):
        if element.is_symlink():
            deny("symlink in directory tree: " + str(element))
    if not path.is_dir():
        deny("directory does not exist: " + str(path))
    return path


def regular_file(root, rel):
    if rel not in ALL_FILES and rel != "SHA256SUMS.txt":
        deny("file is not allowlisted: " + rel)
    file = root / rel
    for parent in (file.parent, *tuple(file.parent.parents)):
        if parent == root.parent:
            break
        if parent.is_symlink():
            deny("source parent is a symlink: " + str(parent))
    try:
        mode = file.lstat().st_mode
    except FileNotFoundError:
        deny("missing file: " + rel)
    if not stat.S_ISREG(mode):
        deny("not a regular file: " + rel)
    return file


def read_sha_sums(source):
    lines = regular_file(source, "SHA256SUMS.txt").read_text("ascii").splitlines()
    sums = {}
    for line in lines:
        parts = re.fullmatch(r"([0-9a-f]{64})  ([a-z0-9][a-z0-9._/-]{0,150})", line)
        if not parts:
            deny("invalid checksums format")
        hash_value, rel = parts.groups()
        if rel not in ALL_FILES or rel in sums:
            deny("unexpected or duplicate SHA256SUMS entry: " + rel)
        sums[rel] = hash_value
    if set(sums) != ALL_FILES:
        deny("SHA256SUMS must pin exactly eight assets and index/poster/manifest")
    return sums


def read_manifest(source, pin_file):
    manifest_file = regular_file(source, "manifest.json")
    pin_file = Path(pin_file).absolute()
    if pin_file.is_symlink() or not pin_file.is_file():
        deny("expected independent V48 pin JSON file")
    pin = json.loads(pin_file.read_text("utf-8"))
    manifest = json.loads(manifest_file.read_text("utf-8"))
    if manifest.get("releaseCandidate") != "V48" or manifest.get("paidCheckoutEnabled") is not False:
        deny("V48 manifest is not owner-local checkout-free candidate")
    if pin.get("localCaptionRevision") != "V48.1_ACCESSIBILITY_FIX_NO_VIDEO_OR_AUDIO_CHANGE":
        deny("V48.1 immutable repo pin is missing")
    if pin.get("releaseDecision") != "NO_GO" or pin.get("publicationAuthorized") is not False:
        deny("pin must never fake a past public premiere")
    if len(pin.get("assets", [])) != 8 or len(manifest.get("assets", [])) != 8:
        deny("expected four MP4 + four WebVTT")
    pins = {a.get("id"): a for a in pin["assets"]}
    assets = {a.get("id"): a for a in manifest["assets"]}
    if set(pins) != set(MEDIA) or set(assets) != set(MEDIA):
        deny("unexpected asset identities")
    for name, relative in MEDIA.items():
        entry, fixed = assets[name], pins[name]
        if entry.get("path") != relative or fixed.get("path") != relative:
            deny("candidate has unexpected path for " + name)
        if entry.get("sha256") != fixed.get("sha256") or entry.get("bytes") != fixed.get("bytes"):
            deny("candidate differs from independently pinned GitHub SHA/size: " + name)
        if not HEX.fullmatch(entry["sha256"]) or not isinstance(entry["bytes"], int) or entry["bytes"] <= 0:
            deny("invalid pinned media digest or length")
    return manifest, pin


def verify_source(source, pin_file):
    source = real_dir(source)
    manifest, pin = read_manifest(source, pin_file)
    sums = read_sha_sums(source)
    if not regular_file(source, "index.html").read_bytes()[:50].lower().startswith(b"<!doctype html"):
        deny("unexpected film page header")
    if not regular_file(source, "assets/osa-premiere-poster.jpg").read_bytes().startswith(b"\xff\xd8\xff"):
        deny("poster JPEG signature mismatch")
    total_bytes = 0
    for rel in sorted(ALL_FILES):
        file = regular_file(source, rel)
        expected = sums[rel]
        actual = sha256_file(file)
        if actual != expected:
            deny("SHA256SUMS mismatch: " + rel)
        if rel in EXTRA_PIN and actual != EXTRA_PIN[rel]:
            deny("immutable GitHub shell pin mismatch: " + rel)
        total_bytes += file.stat().st_size
    for asset in pin["assets"]:
        rel = asset["path"]
        file = regular_file(source, rel)
        if file.stat().st_size != asset["bytes"] or sha256_file(file) != asset["sha256"]:
            deny("GitHub pinned media mismatch: " + rel)
        with file.open("rb") as fp:
            first = fp.read(16)
        if rel.endswith(".mp4") and first[4:8] != b"ftyp":
            deny("video signature is not MP4: " + rel)
        if rel.endswith(".vtt") and not first.startswith(b"WEBVTT"):
            deny("subtitle signature is not WebVTT: " + rel)
    return {"assets": 8, "mediaBytes": sum(a["bytes"] for a in pin["assets"]), "files": len(ALL_FILES), "totalBytes": total_bytes}


def ensure_media_root(root):
    root = real_dir(root)
    release_dir = root / "releases"
    if release_dir.is_symlink():
        deny("releases directory must not be symlink")
    release_dir.mkdir(mode=0o755, exist_ok=True)
    release_dir.chmod(0o755)
    return root, release_dir


def check_id(value):
    if not RELEASE_RE.fullmatch(value):
        deny("invalid release ID")
    return value


def stage(source, pin, root, release_id):
    release_id = check_id(release_id)
    evidence = verify_source(source, pin)
    root, releases = ensure_media_root(root)
    destination = releases / release_id
    if destination.exists() or destination.is_symlink():
        deny("immutable release ID already exists; never overwrite")
    temporary = Path(tempfile.mkdtemp(prefix=".upload-", dir=releases))
    try:
        source = Path(source)
        for rel in sorted(ALL_FILES):
            output = temporary / rel
            output.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(regular_file(source, rel), output)
            output.chmod(0o644)
        shutil.copyfile(regular_file(source, "SHA256SUMS.txt"), temporary / "SHA256SUMS.txt")
        (temporary / "SHA256SUMS.txt").chmod(0o644)
        if verify_source(temporary, pin) != evidence:
            deny("copied staging bytes differ from the user-owned original")
        temporary.chmod(0o755)
        os.replace(temporary, destination)
        print(json.dumps({"status": "STAGED_NOT_PUBLIC", "releaseId": release_id, **evidence}, sort_keys=True))
    except BaseException:
        shutil.rmtree(temporary, ignore_errors=True)
        raise


def read_current(root, name):
    link = root / name
    if not link.exists() and not link.is_symlink():
        return None
    if not link.is_symlink():
        deny(name + " must be absent or a relative symlink")
    target = os.readlink(link)
    if not target.startswith("releases/") or not RELEASE_RE.fullmatch(target.removeprefix("releases/")):
        deny(name + " symlink points outside permitted release directory")
    if (root / target).is_symlink() or not (root / target).is_dir():
        deny(name + " points to a missing or symlinked release")
    return target


def replace_link(root, name, target):
    temporary = root / ("." + name + ".tmp")
    if temporary.exists() or temporary.is_symlink():
        deny("an in-progress activation exists")
    os.symlink(target, temporary)
    try:
        os.replace(temporary, root / name)
    finally:
        if temporary.is_symlink():
            temporary.unlink()


def activate(pin, root, release_id):
    release_id = check_id(release_id)
    root, releases = ensure_media_root(root)
    destination = releases / release_id
    if destination.is_symlink() or not destination.is_dir():
        deny("staged release does not exist as a real directory")
    evidence = verify_source(destination, pin)
    previous = read_current(root, "current")
    if previous == "releases/" + release_id:
        deny("release is already active")
    if previous:
        replace_link(root, "previous", previous)
    else:
        stale = root / "previous"
        if stale.is_symlink():
            stale.unlink()
        elif stale.exists():
            deny("previous must not be a regular file")
    replace_link(root, "current", "releases/" + release_id)
    print(json.dumps({"status": "ACTIVATED_HTTP_QA_REQUIRED", "releaseId": release_id,
                      "previous": previous, "publicationVerified": False, **evidence}, sort_keys=True))


def rollback(root):
    root, _ = ensure_media_root(root)
    active = read_current(root, "current")
    if not active:
        deny("there is no active release to roll back")
    previous = read_current(root, "previous")
    if previous:
        replace_link(root, "current", previous)
        (root / "previous").unlink()
    else:
        (root / "current").unlink()
    print(json.dumps({"status": "ROLLED_BACK", "from": active, "to": previous}, sort_keys=True))


def main(argv):
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="command", required=True)
    for command in ("verify", "stage", "activate"):
        p = sub.add_parser(command)
        if command != "activate":
            p.add_argument("--source", required=True, help="unpacked owner V48.1 full archive")
        p.add_argument("--pin", required=True, help="V48.1 immutable master GitHub JSON")
        if command != "verify":
            p.add_argument("--root", required=True, help="host media root, outside frontend HTML")
            p.add_argument("--release-id", required=True)
    p = sub.add_parser("rollback")
    p.add_argument("--root", required=True)
    args = parser.parse_args(argv)
    if args.command == "verify":
        print(json.dumps({"status": "VERIFIED_NOT_PUBLISHED", **verify_source(args.source, args.pin)}, sort_keys=True))
    elif args.command == "stage":
        stage(args.source, args.pin, args.root, args.release_id)
    elif args.command == "activate":
        activate(args.pin, args.root, args.release_id)
    elif args.command == "rollback":
        rollback(args.root)
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main(sys.argv[1:]))
    except (GateError, OSError, ValueError, KeyError, json.JSONDecodeError) as error:
        print("OSA_V49_HOLD: " + str(error), file=sys.stderr)
        sys.exit(1)
