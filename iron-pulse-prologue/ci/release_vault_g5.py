#!/usr/bin/env python3
"""IRON PULSE G5 / offline release vault.

Real distribution files, no cloud deployment, no signing keys, no fabricated
production approval. SHA-256 detects damage relative to a trusted CI receipt;
it does not provide a digital signature or certify AAA/physical hardware.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import shutil
import stat
import tempfile
import zipfile
from pathlib import Path, PurePosixPath

SCHEMA = "IRON_PULSE_RELEASE_VAULT_G5"
STATE_SCHEMA = "IRON_PULSE_RELEASE_POINTER_G5"
MANIFEST_NAME = "meta/release-manifest.json"
MAX_FILES = 70
MAX_FILE_BYTES = 125_000_000
MAX_TOTAL_BYTES = 250_000_000

SITE_CORE = (
    "index.html", "app.js", "styles.css", "preflight.js", "preflight.css",
    "manifest.webmanifest", "sw.js", "assets/gameplay-proof.png",
    "assets/build-proof.json", "assets/iron-pulse-mark.svg",
    "play/index.html", "play/index.js", "play/index.wasm", "play/index.pck",
)
SITE_OPTIONAL = (
    "play/index.audio.worklet.js", "play/index.audio.position.worklet.js",
    "play/index.png", "play/index.icon.png", "play/index.apple-touch-icon.png",
)
WINDOWS_FILES = ("IRON_PULSE_BLACKOUT.exe", "IRON_PULSE_BLACKOUT.pck")
PROOF_FILES = ("SOURCE_SHA.txt", "SHA256SUMS.txt", "WORLD_SHA256SUMS.txt",
               "V12_SOURCE_REVIEW.json", "RELEASE_HOLD.txt")
ALLOWED = (
    {"site/" + name for name in SITE_CORE + SITE_OPTIONAL}
    | {"windows/" + name for name in WINDOWS_FILES}
    | {"proof/" + name for name in PROOF_FILES}
)
REQUIRED = (
    {"site/" + name for name in SITE_CORE}
    | {"windows/" + name for name in WINDOWS_FILES}
    | {"proof/" + name for name in PROOF_FILES}
)


class VaultError(RuntimeError):
    pass


def require(condition: bool, message: str) -> None:
    if not condition:
        raise VaultError(message)


def sha_ok(value: str) -> bool:
    return re.fullmatch(r"[0-9a-f]{40}", value) is not None


def hash_ok(value: str) -> bool:
    return re.fullmatch(r"[0-9a-f]{64}", value) is not None


def digest(path: Path) -> str:
    hasher = hashlib.sha256()
    with path.open("rb") as source:
        for block in iter(lambda: source.read(1024 * 1024), b""):
            hasher.update(block)
    return hasher.hexdigest()


def canonical(obj: dict) -> bytes:
    return (json.dumps(obj, ensure_ascii=False, sort_keys=True,
                       separators=(",", ":")) + "\n").encode("utf-8")


def safe_file(path: Path, root: Path) -> Path:
    # Reject symlinks in every path component, not just the final file.
    root = root.absolute()
    path = path.absolute()
    require(path.is_relative_to(root), f"File escapes release root: {path}")
    current = root
    require(not current.is_symlink(), f"Symlink release root: {root}")
    for segment in path.relative_to(root).parts:
        current = current / segment
        require(not current.is_symlink(), f"Symlink in release data: {current}")
    require(path.is_file(), f"Mandatory file missing: {path}")
    return path


def inputs_from_build(site: Path, web: Path, windows: Path,
                      proof: Path, source_sha: str) -> dict[str, Path]:
    require(sha_ok(source_sha), "Expected exact 40-character source commit SHA")
    site, web, windows, proof = (x.absolute() for x in (site, web, windows, proof))
    require(all(x.is_dir() and not x.is_symlink() for x in (site, web, windows, proof)),
            "Input directories must exist and must not be symlinks")
    require(site.parent == web.parent == windows.parent == proof.parent,
            "Only one exact build root is accepted; no mixed builds")
    root = site.parent
    source = safe_file(proof / "SOURCE_SHA.txt", proof).read_text(encoding="utf-8").strip()
    require(source == source_sha, "Source SHA does not match exact exported build")
    outputs: dict[str, Path] = {}
    for name in SITE_CORE:
        outputs["site/" + name] = safe_file(site / name, site)
    for name in SITE_OPTIONAL:
        candidate = site / name
        if candidate.exists():
            outputs["site/" + name] = safe_file(candidate, site)
    for name in WINDOWS_FILES:
        outputs["windows/" + name] = safe_file(windows / name, windows)
    for name in PROOF_FILES:
        outputs["proof/" + name] = safe_file(proof / name, proof)
    require(REQUIRED.issubset(outputs.keys()), "Incomplete Godot + world distribution")
    require(outputs["site/play/index.wasm"].stat().st_size > 1_000_000,
            "Godot WebAssembly export is absent")
    require(outputs["windows/IRON_PULSE_BLACKOUT.exe"].stat().st_size > 10_000_000,
            "Real Windows executable is absent")
    require(outputs["site/play/index.wasm"].open("rb").read(4) == b"\0asm",
            "Expected actual WebAssembly magic")
    require(outputs["windows/IRON_PULSE_BLACKOUT.exe"].open("rb").read(2) == b"MZ",
            "Expected actual PE executable header")
    require(outputs["windows/IRON_PULSE_BLACKOUT.pck"].open("rb").read(4) == b"GDPC",
            "Expected Godot package header")
    proof_manifest = json.loads(
        outputs["site/assets/build-proof.json"].read_text(encoding="utf-8"))
    require(proof_manifest.get("source_sha") == source_sha and
            proof_manifest.get("status") == "SOFTWARE_PREVIEW" and
            proof_manifest.get("production_approved") is False and
            proof_manifest.get("hardware_tested") is False and
            proof_manifest.get("runtime_verified_against_export") is True,
            "Godot WORLD source evidence inconsistent or falsely approved")
    declared = proof_manifest.get("files")
    require(isinstance(declared, dict) and set(declared).issubset(
        {name[5:] for name in outputs if name.startswith("site/")}),
        "World build proof lists unknown or missing files")
    for relative, info in declared.items():
        candidate = outputs["site/" + relative]
        require(info.get("sha256") == digest(candidate) and
                info.get("size") == candidate.stat().st_size,
                f"World build-proof mismatch: {relative}")
    require(proof_manifest.get("browser_capture_unchanged_sha256") ==
            digest(outputs["site/assets/gameplay-proof.png"]),
            "Real gameplay screenshot differs from Chromium proof")
    # Independently re-check both upstream core build manifests. A single
    # unrelated Windows or WebGL binary cannot be silently mixed in.
    for proof_name in ("SHA256SUMS.txt", "WORLD_SHA256SUMS.txt"):
        lines = (proof / proof_name).read_text(encoding="utf-8").splitlines()
        require(bool(lines) and len(lines) <= 20, "Malformed SHA manifest")
        seen = set()
        for line in lines:
            match = re.fullmatch(r"([0-9a-f]{64})  (web|windows|world-preview)/([A-Za-z0-9_./-]+)", line)
            require(match is not None, f"Unexpected SHA manifest entry: {line!r}")
            expected, folder, relative = match.groups()
            require(".." not in PurePosixPath(relative).parts, "Checksum path traversal")
            source_dir = {"web": web, "windows": windows, "world-preview": site}[folder]
            source_path = safe_file(source_dir / relative, source_dir)
            require(digest(source_path) == expected,
                    f"Build checksum mismatch: {folder}/{relative}")
            seen.add(f"{folder}/{relative}")
        if proof_name == "SHA256SUMS.txt":
            require({f"windows/{n}" for n in WINDOWS_FILES}.issubset(seen) and
                    "web/index.wasm" in seen, "Windows/WebGL build SHA proof absent")
        else:
            require({"world-preview/play/index.wasm", "world-preview/index.html",
                     "world-preview/assets/gameplay-proof.png"}.issubset(seen),
                    "World portal source proof absent")
    for name in ("index.html", "index.js", "index.wasm", "index.pck"):
        require(digest(outputs["site/play/" + name]) == digest(safe_file(web / name, web)),
                "Web portal runtime differs from actual exported Godot binary")
    return outputs


def manifest_for(files: dict[str, Path], source_sha: str) -> dict:
    return {
        "schema": SCHEMA,
        "source_sha": source_sha,
        "status": "TECHNICAL_PREVIEW_RELEASE_HOLD",
        "production_approved": False,
        "physical_devices_certified": False,
        "independent_aaa_certified": False,
        "cryptographically_signed": False,
        "note": "SHA-256 is integrity evidence, not signature, independent hardware QA or launch permission",
        "files": {name: {"sha256": digest(path), "bytes": path.stat().st_size}
                  for name, path in sorted(files.items())},
    }


def zip_info(name: str) -> zipfile.ZipInfo:
    info = zipfile.ZipInfo(name, date_time=(1980, 1, 1, 0, 0, 0))
    info.compress_type = zipfile.ZIP_DEFLATED
    info.create_system = 3
    info.external_attr = (0o100644 << 16)
    return info


def package(site: Path, web: Path, windows: Path, proof: Path,
            source_sha: str, destination: Path, receipt: Path) -> dict:
    files = inputs_from_build(site, web, windows, proof, source_sha)
    require(not destination.exists() and not receipt.exists(),
            "Never overwrite an existing release archive or receipt")
    destination.parent.mkdir(parents=True, exist_ok=True)
    receipt.parent.mkdir(parents=True, exist_ok=True)
    manifest = manifest_for(files, source_sha)
    require(set(manifest["files"]).issubset(ALLOWED), "Unapproved files in release")
    temp = destination.with_name(destination.name + ".building")
    require(not temp.exists(), "Unfinished release package exists; investigate first")
    try:
        with zipfile.ZipFile(temp, "w", compression=zipfile.ZIP_DEFLATED,
                             compresslevel=6, allowZip64=True) as archive:
            for name, path in sorted(files.items()):
                with path.open("rb") as src, archive.open(zip_info(name), "w",
                                                          force_zip64=True) as dst:
                    shutil.copyfileobj(src, dst, 1024 * 1024)
            archive.writestr(zip_info(MANIFEST_NAME), canonical(manifest))
        checked = verify_archive(temp, expected_sha=source_sha)
        os.replace(temp, destination)
        receipt_data = {
            "schema": SCHEMA,
            "source_sha": source_sha,
            "package_sha256": digest(destination),
            "package_bytes": destination.stat().st_size,
            "files_verified": checked["file_count"],
            "production_approved": False,
            "hardware_tested": False,
            "release_hold": True,
        }
        receipt.write_bytes(canonical(receipt_data))
        return receipt_data
    finally:
        if temp.exists():
            temp.unlink()


def _validated_zip(archive: zipfile.ZipFile) -> tuple[dict, dict[str, zipfile.ZipInfo]]:
    members = archive.infolist()
    require(len(members) <= MAX_FILES + 1, "Excessive release member count")
    info_by_name = {}
    folded = set()
    total = 0
    for info in members:
        name = info.filename
        candidate = PurePosixPath(name)
        require(not info.is_dir() and "\\" not in name and not name.startswith("/") and
                not name.endswith("/") and
                candidate.as_posix() == name and
                not any(piece in ("", ".", "..") for piece in candidate.parts),
                f"Unsafe release ZIP path: {name}")
        require(name in ALLOWED or name == MANIFEST_NAME, f"Unapproved release entry: {name}")
        require(name not in info_by_name and name.casefold() not in folded,
                f"Duplicate/case-aliased ZIP member: {name}")
        kind = stat.S_IFMT(info.external_attr >> 16)
        require(kind in (0, stat.S_IFREG), f"Symlink/device entry prohibited: {name}")
        require(0 < info.file_size <= MAX_FILE_BYTES, f"Invalid decompressed file size: {name}")
        require(info.compress_size > 0, f"Invalid compressed file: {name}")
        total += info.file_size
        require(total <= MAX_TOTAL_BYTES, "Unsafe release total decompressed size")
        info_by_name[name] = info
        folded.add(name.casefold())
    require(MANIFEST_NAME in info_by_name and REQUIRED.issubset(info_by_name),
            "Missing manifest, engine or proof in release")
    require(info_by_name[MANIFEST_NAME].file_size < 100_000,
            "Manifest unexpectedly large")
    with archive.open(MANIFEST_NAME) as f:
        manifest = json.load(f)
    require(isinstance(manifest, dict) and manifest.get("schema") == SCHEMA and
            manifest.get("status") == "TECHNICAL_PREVIEW_RELEASE_HOLD" and
            manifest.get("production_approved") is False and
            manifest.get("physical_devices_certified") is False and
            manifest.get("independent_aaa_certified") is False and
            manifest.get("cryptographically_signed") is False and
            sha_ok(str(manifest.get("source_sha", ""))),
            "Release is unsigned preview only; no fake production authorization")
    records = manifest.get("files")
    require(isinstance(records, dict) and set(records) ==
            (set(info_by_name) - {MANIFEST_NAME}),
            "Manifest must cover EVERY and ONLY archive file")
    return manifest, info_by_name


def verify_archive(path: Path, expected_sha: str = "",
                   expected_bundle_sha256: str = "") -> dict:
    require(path.is_file() and not path.is_symlink(), "Release archive missing or symlinked")
    if expected_bundle_sha256:
        require(hash_ok(expected_bundle_sha256), "Bad pinned bundle SHA-256")
        require(digest(path) == expected_bundle_sha256,
                "Archive differs from externally trusted build hash")
    with zipfile.ZipFile(path) as archive:
        manifest, infos = _validated_zip(archive)
        if expected_sha:
            require(manifest["source_sha"] == expected_sha,
                    "Release does not match pinned source commit")
        for name, info in infos.items():
            if name == MANIFEST_NAME:
                continue
            record = manifest["files"][name]
            require(type(record) is dict and record.get("bytes") == info.file_size and
                    hash_ok(str(record.get("sha256", ""))),
                    "Manifest has corrupted file size or digest: " + name)
            sha = hashlib.sha256()
            count = 0
            with archive.open(info) as stream:
                for chunk in iter(lambda: stream.read(1024 * 1024), b""):
                    sha.update(chunk)
                    count += len(chunk)
                    require(count <= info.file_size, "ZIP decompressed-size mismatch")
            require(count == info.file_size and sha.hexdigest() == record["sha256"],
                    "Release file integrity FAILED: " + name)
        with archive.open("site/assets/build-proof.json") as raw:
            proof = json.load(raw)
        require(proof.get("source_sha") == manifest["source_sha"] and
                proof.get("status") == "SOFTWARE_PREVIEW" and
                proof.get("production_approved") is False and
                proof.get("hardware_tested") is False,
                "Release inner Godot evidence disagrees with source/status")
        with archive.open("proof/SOURCE_SHA.txt") as raw:
            require(raw.read().decode("utf-8").strip() == manifest["source_sha"],
                    "Release has inconsistent source SHA")
        require(infos["site/play/index.wasm"].file_size > 1_000_000 and
                infos["windows/IRON_PULSE_BLACKOUT.exe"].file_size > 10_000_000,
                "Not actual substantial Godot WebGL/Windows artifacts")
        with archive.open("site/play/index.wasm") as f:
            require(f.read(4) == b"\0asm", "Invalid WebAssembly magic")
        with archive.open("windows/IRON_PULSE_BLACKOUT.exe") as f:
            require(f.read(2) == b"MZ", "Invalid Windows executable magic")
        with archive.open("windows/IRON_PULSE_BLACKOUT.pck") as f:
            require(f.read(4) == b"GDPC", "Invalid Godot package magic")
        return {
            "schema": SCHEMA,
            "source_sha": manifest["source_sha"],
            "file_count": len(infos) - 1,
            "bytes_uncompressed": sum(i.file_size for i in infos.values()),
            "package_sha256": digest(path),
            "verified": True,
            "release_hold": True,
            "production_approved": False,
        }


def vault_dir(root: Path) -> Path:
    require(not root.is_symlink(), "Vault root cannot be a symlink")
    root.mkdir(parents=True, exist_ok=True)
    for suffix in ("releases", "state", "state/receipts"):
        part = root / suffix
        require(not part.is_symlink(), "Vault directories cannot be symlinks")
        part.mkdir(parents=True, exist_ok=True)
    return root.absolute()


def _verified_staged(root: Path, sha: str) -> dict:
    require(sha_ok(sha), "Release id must be exact commit SHA")
    dest = root / "releases" / sha
    require(dest.is_dir() and not dest.is_symlink(), "Requested release is not staged")
    metadata = safe_file(dest / MANIFEST_NAME, dest)
    manifest = json.loads(metadata.read_text(encoding="utf-8"))
    require(manifest.get("schema") == SCHEMA and manifest.get("source_sha") == sha and
            manifest.get("production_approved") is False, "Bad staged release manifest")
    records = manifest.get("files", {})
    require(isinstance(records, dict) and REQUIRED.issubset(records) and
            set(records).issubset(ALLOWED), "Unsafe or incomplete stage")
    staged_paths = {p.relative_to(dest).as_posix() for p in dest.rglob("*") if p.is_file()}
    require(staged_paths == set(records) | {MANIFEST_NAME},
            "Unexpected, missing or unsafe files in staged release")
    for relative, record in records.items():
        candidate = safe_file(dest / relative, dest)
        require(candidate.stat().st_size == record["bytes"] and
                digest(candidate) == record["sha256"],
                "Staged release changed on disk: " + relative)
    receipt = root / "state" / "receipts" / (sha + ".json")
    require(receipt.is_file() and not receipt.is_symlink(), "Stage has no CI package receipt")
    stored = json.loads(receipt.read_text(encoding="utf-8"))
    require(stored.get("source_sha") == sha and
            hash_ok(str(stored.get("package_sha256", ""))) and
            stored.get("production_approved") is False,
            "Staged package receipt invalid")
    return {"sha": sha, "files": len(records), "package_sha256": stored["package_sha256"]}


def stage(path: Path, root: Path, source_sha: str, bundle_hash: str) -> dict:
    require(hash_ok(bundle_hash), "Stage requires EXTERNALLY PINNED archive SHA-256")
    verified = verify_archive(path, source_sha, bundle_hash)
    root = vault_dir(root)
    target = root / "releases" / source_sha
    receipt_path = root / "state" / "receipts" / (source_sha + ".json")
    if target.exists() or receipt_path.exists():
        previous = _verified_staged(root, source_sha)
        require(previous["package_sha256"] == bundle_hash,
                "Immutable release already exists with different package hash")
        return {"status": "already-staged", **previous}
    working = Path(tempfile.mkdtemp(prefix=".g5-stage-", dir=root / "releases"))
    try:
        with zipfile.ZipFile(path) as archive:
            manifest, infos = _validated_zip(archive)
            for name in sorted(infos):
                output = working / name
                output.parent.mkdir(parents=True, exist_ok=True)
                with archive.open(name) as src, output.open("xb") as dst:
                    shutil.copyfileobj(src, dst, 1024 * 1024)
        # Verify all files before making the staged directory visible.
        for name, record in manifest["files"].items():
            output = safe_file(working / name, working)
            require(output.stat().st_size == record["bytes"] and
                    digest(output) == record["sha256"],
                    "Staging produced altered payload: " + name)
        os.replace(working, target)
        receipt_path.write_bytes(canonical({
            "schema": SCHEMA, "source_sha": source_sha,
            "package_sha256": bundle_hash, "production_approved": False,
            "hardware_tested": False,
        }))
        return {"status": "staged-not-deployed", **_verified_staged(root, source_sha)}
    finally:
        if working.exists():
            shutil.rmtree(working)


def _pointer(root: Path) -> dict:
    path = root / "state" / "current.json"
    if not path.exists():
        return {"schema": STATE_SCHEMA, "current": None,
                "previous": None, "generation": 0,
                "deployment_performed": False}
    require(not path.is_symlink(), "Pointer is a symlink")
    data = json.loads(path.read_text(encoding="utf-8"))
    require(data.get("schema") == STATE_SCHEMA and type(data.get("generation")) is int and
            type(data.get("deployment_performed")) is bool and
            data.get("deployment_performed") is False,
            "Invalid local-only pointer; do not assume live deployment")
    return data


def _put_pointer(root: Path, payload: dict) -> None:
    path = root / "state" / "current.json"
    temp = root / "state" / "current.json.next"
    require(not temp.exists(), "Unresolved pointer update; do not overwrite")
    try:
        with temp.open("x", encoding="utf-8") as f:
            f.write(canonical(payload).decode("utf-8"))
            f.flush()
            os.fsync(f.fileno())
        os.replace(temp, path)
    finally:
        if temp.exists():
            temp.unlink()


def _compare_expected(pointer: dict, expected_current: str) -> None:
    current = pointer.get("current")
    expected = None if expected_current == "none" else expected_current
    require(expected is None or sha_ok(expected), "Invalid --expected-current")
    require(current == expected, "CAS mismatch: selected release changed; abort")


def activate(root: Path, source_sha: str, expected_current: str) -> dict:
    root = vault_dir(root)
    current = _pointer(root)
    _compare_expected(current, expected_current)
    release = _verified_staged(root, source_sha)
    require(current["current"] != source_sha, "This release is already selected")
    next_pointer = {
        "schema": STATE_SCHEMA,
        "current": source_sha,
        "previous": current["current"],
        "generation": current["generation"] + 1,
        "deployment_performed": False,
        "status": "LOCAL_PREVIEW_RELEASE_POINTER_ONLY",
        "package_sha256": release["package_sha256"],
        "production_approved": False,
    }
    _put_pointer(root, next_pointer)
    return next_pointer


def rollback(root: Path, expected_current: str) -> dict:
    root = vault_dir(root)
    current = _pointer(root)
    _compare_expected(current, expected_current)
    previous = current.get("previous")
    require(isinstance(previous, str) and sha_ok(previous),
            "No previous staged release to restore")
    release = _verified_staged(root, previous)
    next_pointer = {
        "schema": STATE_SCHEMA,
        "current": previous,
        "previous": current["current"],
        "generation": current["generation"] + 1,
        "deployment_performed": False,
        "status": "LOCAL_PREVIEW_ROLLBACK_POINTER_ONLY",
        "package_sha256": release["package_sha256"],
        "production_approved": False,
    }
    _put_pointer(root, next_pointer)
    return next_pointer


def status(root: Path) -> dict:
    root = vault_dir(root)
    pointer = _pointer(root)
    if pointer.get("current"):
        pointer["current_verified"] = _verified_staged(root, pointer["current"])
    return pointer


def main() -> None:
    p = argparse.ArgumentParser(description=__doc__)
    commands = p.add_subparsers(dest="command", required=True)
    pack = commands.add_parser("pack")
    for flag in ("site", "web", "windows", "proof", "output", "receipt"):
        pack.add_argument("--" + flag, required=True, type=Path)
    pack.add_argument("--source-sha", required=True)
    verify = commands.add_parser("verify")
    verify.add_argument("--archive", required=True, type=Path)
    verify.add_argument("--source-sha", default="")
    verify.add_argument("--bundle-sha256", default="")
    staging = commands.add_parser("stage")
    staging.add_argument("--archive", required=True, type=Path)
    staging.add_argument("--vault", required=True, type=Path)
    staging.add_argument("--source-sha", required=True)
    staging.add_argument("--bundle-sha256", required=True)
    act = commands.add_parser("activate")
    act.add_argument("--vault", required=True, type=Path)
    act.add_argument("--source-sha", required=True)
    act.add_argument("--expected-current", required=True)
    back = commands.add_parser("rollback")
    back.add_argument("--vault", required=True, type=Path)
    back.add_argument("--expected-current", required=True)
    state = commands.add_parser("status")
    state.add_argument("--vault", required=True, type=Path)
    args = p.parse_args()
    try:
        if args.command == "pack":
            result = package(args.site, args.web, args.windows, args.proof,
                             args.source_sha, args.output, args.receipt)
        elif args.command == "verify":
            result = verify_archive(args.archive, args.source_sha, args.bundle_sha256)
        elif args.command == "stage":
            result = stage(args.archive, args.vault, args.source_sha, args.bundle_sha256)
        elif args.command == "activate":
            result = activate(args.vault, args.source_sha, args.expected_current)
        elif args.command == "rollback":
            result = rollback(args.vault, args.expected_current)
        else:
            result = status(args.vault)
        print("IRON PULSE G5 RELEASE VAULT PASS: " +
              json.dumps(result, sort_keys=True, ensure_ascii=False))
    except (VaultError, OSError, ValueError, KeyError, zipfile.BadZipFile,
            json.JSONDecodeError) as exc:
        raise SystemExit("IRON PULSE G5 RELEASE VAULT FAIL: " + str(exc)) from exc


if __name__ == "__main__":
    main()
