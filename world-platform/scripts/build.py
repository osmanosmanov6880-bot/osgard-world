#!/usr/bin/env python3
"""W76 WORLD PLATFORM: build REAL original Godot WebGL + premium game platform.

Never substitutes images, mocks or fake canvas for index.wasm/index.pck.
Validates the exact engine-generated evidence manifest and the actual bytes;
publishes nothing. Produces deterministic local distributable ZIP only.
Python 3.10+ stdlib. No network, credentials, telemetry transmission.
"""
from __future__ import annotations
import argparse
import hashlib
import json
import re
import shutil
import stat
import sys
import zipfile
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[1]
GAME_SOURCE_SHA = "73ef81b54cb42831cafd9ac8fa69c5807cd8dc8d"
W74_CI = "https://github.com/osmanosmanov6880-bot/osgard-world/actions/runs/40650956529"
EXPECTED_GODOT = "4.4.1"
EVIDENCE_SCHEMA = "OSGARD_W33_GODOT_WEB_BYTES_V1"
SCHEMA = "LAST_FRONTIER_WORLD_PLATFORM_V1"
SAFE_NAME = re.compile(r"^index\.[a-zA-Z0-9.-]+$")
FULL_SHA = re.compile(r"^[0-9a-f]{40}$")
HEX_SHA = re.compile(r"^[a-f0-9]{64}$")
MAX_GAME_TOTAL = 130_000_000
MAX_FILE = 95_000_000
SHELL = (
    "index.html", "styles.css", "app.mjs", "core.mjs", "sw.js", "icon.svg",
    "manifest.webmanifest", "robots.txt", "START_WINDOWS.bat",
    "START_LINUX_MAC.sh", "README.txt",
)


class WorldBuildError(ValueError):
    pass


def file_sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as reader:
        for chunk in iter(lambda: reader.read(131072), b""):
            digest.update(chunk)
    return digest.hexdigest()


def make_manifest(game: Path, platform_sha: str) -> dict[str, Any]:
    if not FULL_SHA.fullmatch(platform_sha):
        raise WorldBuildError("Exact platform Git commit SHA required")
    proof_path = game / "evidence.json"
    if not proof_path.is_file() or proof_path.is_symlink():
        raise WorldBuildError("Original Godot export evidence.json is missing")
    proof = json.loads(proof_path.read_text(encoding="utf-8"))
    if proof.get("schema") != EVIDENCE_SCHEMA:
        raise WorldBuildError("Not an original Godot WebAssembly manifest")
    if proof.get("source_commit") != platform_sha:
        raise WorldBuildError("Original game export not built from exact W76 source SHA")
    if proof.get("godot_release") != EXPECTED_GODOT:
        raise WorldBuildError("Original Godot version mismatch")
    entries = proof.get("files")
    if not isinstance(entries, list) or not (8 <= len(entries) <= 18):
        raise WorldBuildError("Unexpected number of genuine exported game files")
    listed = set()
    validated = []
    total = 0
    for item in entries:
        if not isinstance(item, dict):
            raise WorldBuildError("Malformed Godot file entry")
        name = item.get("name")
        raw_hash = item.get("sha256")
        reported_size = item.get("bytes")
        if not isinstance(name, str) or not SAFE_NAME.fullmatch(name):
            raise WorldBuildError("Unexpected / untrusted game path")
        if name in listed:
            raise WorldBuildError("Duplicate original Godot engine file")
        if not isinstance(raw_hash, str) or not HEX_SHA.fullmatch(raw_hash):
            raise WorldBuildError("Missing valid source-bound SHA256")
        if type(reported_size) is not int or reported_size < 1 or reported_size > MAX_FILE:
            raise WorldBuildError("Invalid original Godot asset byte count")
        candidate = game / name
        if not candidate.is_file() or candidate.is_symlink():
            raise WorldBuildError("Original Godot native binary is absent")
        if candidate.stat().st_size != reported_size:
            raise WorldBuildError("Actual native engine byte size mismatch: " + name)
        if file_sha256(candidate) != raw_hash:
            raise WorldBuildError("Actual engine SHA256 differs from export: " + name)
        listed.add(name)
        total += reported_size
        validated.append({
            "path": "game/" + name,
            "bytes": reported_size,
            "sha256": raw_hash,
        })
    if total >= MAX_GAME_TOTAL:
        raise WorldBuildError("Unexpected total native export size")
    if "index.wasm" not in listed or "index.pck" not in listed or (
            "index.html" not in listed or "index.js" not in listed):
        raise WorldBuildError("Genuine playable WebAssembly/PCK/HTML/JS missing")
    with (game / "index.wasm").open("rb") as reader:
        if reader.read(4) != b"\0asm":
            raise WorldBuildError("Not a genuine WebAssembly game binary")
    with (game / "index.pck").open("rb") as reader:
        if reader.read(4) != b"GDPC":
            raise WorldBuildError("Not an authentic Godot PCK file")
    validated.sort(key=lambda x: x["path"])
    return {
        "schema": SCHEMA,
        "sourceSha": GAME_SOURCE_SHA,
        "platformSourceSha": platform_sha,
        "softwareCiUrl": W74_CI,
        "gameEngine": "Godot " + EXPECTED_GODOT,
        "nativeAcceptedSuitesOnOriginalGame": 11,
        "gameFiles": validated,
        "totalOriginalBytes": total,
        "softwareVerified": True,
        "productionApproved": False,
        "releaseStatus": "PRODUCTION_HOLD",
        "firstTimeHumanSessionsVerified": 0,
        "consumerGpu60FpsCertified": False,
        "thirdPartyTrademarkCleared": False,
        "realOnlineMultiplayer": False,
        "realCloudAccounts": False,
        "originalGodotExportEvidenceSha256": file_sha256(proof_path),
        "validationMeaning": (
            "Game binaries verified against exact local Godot export for "
            "this W76 source; original game SHA refers to accepted W74 code. "
            "This is not an independent commercial AAA hardware certification."
        ),
    }


def generate(assets: Path, out: Path, platform_sha: str, archive: Path | None):
    if out.exists():
        raise WorldBuildError("Output must be a new path: refusing to overwrite or delete other data")
    manifest = make_manifest(assets, platform_sha)
    out.mkdir(parents=True)
    (out / "game").mkdir()
    for name in SHELL:
        source = ROOT / name
        if not source.is_file() or source.is_symlink():
            raise WorldBuildError("Missing controlled platform source: " + name)
        shutil.copy2(source, out / name)
    for item in manifest["gameFiles"]:
        name = Path(item["path"]).name
        shutil.copy2(assets / name, out / "game" / name)
        if file_sha256(out / "game" / name) != item["sha256"]:
            raise WorldBuildError("Game file changed while copying: " + name)
    # Original evidence file is preserved as a separately checkable audit
    # artifact, but never sent to a remote API.
    shutil.copy2(assets / "evidence.json", out / "game" / "evidence.json")
    (out / "release-manifest.json").write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )
    if archive is not None:
        if archive.exists():
            raise WorldBuildError("Archive path exists: will not overwrite")
        archive.parent.mkdir(parents=True, exist_ok=True)
        with zipfile.ZipFile(archive, "w", compression=zipfile.ZIP_DEFLATED,
                             compresslevel=8, allowZip64=True) as writer:
            for path in sorted(out.rglob("*")):
                if not path.is_file():
                    continue
                name = str(path.relative_to(out)).replace("\\", "/")
                if name.startswith("/") or ".." in Path(name).parts:
                    raise WorldBuildError("Unsafe package name")
                info = zipfile.ZipInfo(name, date_time=(2026, 10, 28, 0, 0, 0))
                info.compress_type = zipfile.ZIP_DEFLATED
                info.external_attr = (
                    (0o755 if name.endswith(".sh") else 0o644) << 16
                )
                with path.open("rb") as reader, writer.open(info, "w") as sink:
                    shutil.copyfileobj(reader, sink, 131072)
        # The generated archive can be inspected with unzip -t and the same
        # source manifest, without relying on this Python process afterward.
        with zipfile.ZipFile(archive) as reader:
            bad = reader.testzip()
            if bad:
                raise WorldBuildError("Bad ZIP entry: " + bad)
    summary = {
        "schema": "LAST_FRONTIER_W76_PROVENANCE_AND_DISTRIBUTABLE_V1",
        "platform_commit": platform_sha,
        "game_commit": GAME_SOURCE_SHA,
        "actualGodotWebGlBytes": manifest["totalOriginalBytes"],
        "actualGameBinaryCount": len(manifest["gameFiles"]),
        "realWebAssembly": True,
        "realGodotPCK": True,
        "filesAreSourceHashValidated": True,
        "archive": str(archive) if archive is not None else "",
        "archiveSha256": file_sha256(archive) if archive is not None else "",
        "commercialReleaseAuthorized": False,
        "physicalPlayerTestsInvented": False,
    }
    (out / "WORLD_BUILD_PROOF.json").write_text(
        json.dumps(summary, sort_keys=True, indent=2) + "\n",
        encoding="utf-8",
    )
    print(json.dumps(summary, indent=2))
    return summary


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--game-dir", type=Path, required=True)
    parser.add_argument("--out", type=Path, required=True)
    parser.add_argument("--platform-sha", required=True)
    parser.add_argument("--archive", type=Path)
    args = parser.parse_args()
    try:
        generate(args.game_dir.resolve(), args.out.resolve(),
                 args.platform_sha, args.archive.resolve() if args.archive else None)
    except (WorldBuildError, OSError, ValueError) as error:
        print("W76 ORIGINAL GAME BUILD REJECTED: " + str(error), file=sys.stderr)
        return 2
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
