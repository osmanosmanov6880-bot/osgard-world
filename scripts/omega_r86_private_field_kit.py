#!/usr/bin/env python3
"""EMPIRE Omega R86: private, source-pinned field-evidence collection.

No uploads, network calls, synthetic participant attestations, or release GO.
The real R83 validators remain the single source of machine-evidence rules.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
import stat
import sys
import tempfile
from pathlib import Path

import omega_r83_release_gate as r83
import omega_r80_hardware_evidence as r80

REPO = Path(__file__).resolve().parent.parent
DEFAULT_MANIFEST = REPO / "public/games/omega-3d-preview/release.json"
KIT_SCHEMA = "empire-omega-r86-private-source-pin-v1"
INTAKE_SCHEMA = "empire-omega-r86-operator-session-intake-v1"
REPORT_SCHEMA = "empire-omega-r83-20-sessions-v1"
SUBDIRS = ("web", "campaign", "android", "ios", "players", "art", "review")
PLAYER_FIELDS = (
    "session_id", "participant_code", "observer", "recording_consent",
    "actually_played", "captured_utc", "duration_s", "outcome", "feedback",
    "recording_file",
)


class KitError(ValueError):
    pass


def require(condition: bool, message: str) -> None:
    if not condition:
        raise KitError(message)


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as f:
        while chunk := f.read(1024 * 1024):
            digest.update(chunk)
    return digest.hexdigest()


def private_root(path: Path, *, creating: bool = False) -> Path:
    require(path.is_absolute(), "use an absolute private workspace path")
    require(not path.is_symlink(), "linked workspace is forbidden")
    actual = path.resolve()
    require(not actual.is_relative_to(REPO.resolve()),
            "private player/device evidence must stay OUTSIDE public repository")
    require(not path.parent.is_symlink() and path.parent.is_dir(),
            "workspace parent must be a real existing directory")
    if creating:
        require(not path.exists(), "refusing to replace an existing workspace")
    else:
        require(path.is_dir(), "private workspace does not exist")
        if os.name == "posix":
            require((stat.S_IMODE(path.stat().st_mode) & 0o077) == 0,
                    "workspace permissions too broad: require chmod 700")
        for part in SUBDIRS:
            sub = path / part
            require(sub.is_dir() and not sub.is_symlink(),
                    "missing or linked private evidence directory: " + part)
            if os.name == "posix":
                require((stat.S_IMODE(sub.stat().st_mode) & 0o077) == 0,
                        "private evidence directory too permissive: " + part)
    return path


def manifest_source(manifest_path: Path) -> tuple[str, str]:
    require(not manifest_path.is_symlink(), "release manifest symlink refused")
    manifest = r83.load_object(manifest_path)
    return r83.release_source(manifest), sha256(manifest_path)


def pin_source(root: Path, manifest_path: Path) -> str:
    private_root(root)
    source, digest = manifest_source(manifest_path)
    pin = r83.load_object(root / "source-pin.json")
    require(pin.get("schema") == KIT_SCHEMA and
            pin.get("source_commit") == source and
            pin.get("release_manifest_sha256") == digest,
            "published release manifest changed; open a NEW private workspace")
    return source


def write_new_json(path: Path, payload: dict) -> None:
    fd = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as f:
            json.dump(payload, f, ensure_ascii=False, indent=2)
            f.write("\n")
    except BaseException:
        path.unlink(missing_ok=True)
        raise


def initialize(root: Path, manifest_path: Path) -> dict:
    root = private_root(root, creating=True)
    source, digest = manifest_source(manifest_path)
    root.mkdir(mode=0o700)
    try:
        for part in SUBDIRS:
            (root / part).mkdir(mode=0o700)
        write_new_json(root / "source-pin.json", {
            "schema": KIT_SCHEMA,
            "source_commit": source,
            "release_manifest_sha256": digest,
            "notice": "Local source pin only; NOT an online deployment attestation.",
        })
        # Intentionally zero sessions. Never manufacture twenty player reports.
        write_new_json(root / "players/operator-metadata.template.json", {
            "schema": INTAKE_SCHEMA,
            "source_commit": source,
            "sessions": [],
            "notice": "Fill with 20 real separately consented participants and video files.",
        })
        instructions = (
            "# EMPIRE Omega private R86 field QA workspace\n\n"
            "Keep this directory out of GitHub, cloud/public CI and shared web roots.\n"
            "This is NOT a release certificate. No phone or player is automatically verified.\n\n"
            "1. Copy genuine live-integrity.json and playwright.json into web/.\n"
            "2. Follow docs/EMPIRE_OMEGA_R73_FIELD_ACCEPTANCE.md; keep original\n"
            "   campaign-session.json, video and all 43 PNGs inside campaign/.\n"
            "3. Use scripts/omega_r80_prepare_phone_session.py independently for\n"
            "   Android and iPhone; keep original JSON and video in their folders.\n"
            "4. Make a COPY of players/operator-metadata.template.json as\n"
            "   players/operator-metadata.json, and fill 20 actual distinct user sessions.\n"
            "   Place their 20 separate MP4/WebM recordings alongside metadata.\n"
            "5. Run R86 sessions, then R86 audit; original R83 checks every gate.\n"
            "6. Fill art/art-review.json and four original Godot screenshots from\n"
            "   the documented R83 format and collect the independent licence review.\n"
            "7. Independently inspect every video, real hardware and game frame.\n"
            "   Even all machine checks passing DOES NOT grant commercial/AAA GO.\n"
            "\nPinned game source: " + source + "\n"
        )
        note = root / "PRIVATE-INSTRUCTIONS.md"
        fd = os.open(note, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
        with os.fdopen(fd, "w", encoding="utf-8") as f:
            f.write(instructions)
    except BaseException:
        # Fail closed; never silently reuse a half-initialized private workspace.
        raise
    return {"status": "PRIVATE_WORKSPACE_CREATED_NO_EVIDENCE",
            "source_commit": source, "sessions_collected": 0,
            "production_go": False}


def checked_video_hash(root: Path, name: object) -> str:
    require(isinstance(name, str) and r80.SAFE.fullmatch(name) is not None
            and name not in (".", ".."), "unsafe recording filename")
    require(name.lower().endswith((".mp4", ".webm")),
            "only original MP4/WebM recordings accepted")
    movie = root / name
    require(movie.is_file() and not movie.is_symlink() and
            movie.resolve().parent == root.resolve(),
            "missing, linked or external original recording")
    require(1025 <= movie.stat().st_size <= r80.MAX_RECORDING_BYTES,
            "original video empty or oversized")
    with movie.open("rb") as f:
        first = f.read(16)
    require((name.lower().endswith(".mp4") and first[4:8] == b"ftyp") or
            (name.lower().endswith(".webm") and first[:4] == bytes.fromhex("1a45dfa3")),
            "original recording is not an MP4/WebM container")
    return sha256(movie)


def sessions(root: Path, manifest_path: Path) -> dict:
    source = pin_source(root, manifest_path)
    player_dir = root / "players"
    metadata_path = player_dir / "operator-metadata.json"
    payload = r83.load_object(metadata_path)
    require(payload.get("schema") == INTAKE_SCHEMA and
            payload.get("source_commit") == source, "wrong operator intake/source")
    items = payload.get("sessions")
    require(isinstance(items, list) and len(items) == 20,
            "twenty ACTUAL separately recorded sessions are required")
    normalized = []
    for number, item in enumerate(items, start=1):
        require(isinstance(item, dict), "invalid session " + str(number))
        entry = {field: item.get(field) for field in PLAYER_FIELDS}
        entry["recording_sha256"] = checked_video_hash(player_dir,
                                                        entry["recording_file"])
        normalized.append(entry)
    report = {"schema": REPORT_SCHEMA, "source_commit": source,
              "sessions": normalized}
    output = player_dir / "twenty-sessions.json"
    require(not output.exists() and not output.is_symlink(),
            "refusing to overwrite an existing 20-session report")
    temp_path = None
    try:
        with tempfile.NamedTemporaryFile(
                mode="w", encoding="utf-8", suffix=".json", prefix=".r86-",
                dir=player_dir, delete=False) as file:
            temp_path = Path(file.name)
            json.dump(report, file, ensure_ascii=False, indent=2)
            file.write("\n")
        os.chmod(temp_path, 0o600)
        # Reuse the strict original validator; never trust user-supplied hashes.
        r83.human_sessions(temp_path, source)
        # Atomic create-if-absent: os.replace would overwrite real field work.
        os.link(temp_path, output)
    finally:
        if temp_path:
            temp_path.unlink(missing_ok=True)
    return {
        "status": "FORMAT_AND_BYTES_READY_FOR_INDEPENDENT_HUMAN_REVIEW",
        "source_commit": source, "original_recordings_sha_checked": 20,
        "actual_humans_independently_witnessed": False,
        "production_go": False,
    }


def audit(root: Path, manifest_path: Path) -> dict:
    source = pin_source(root, manifest_path)

    def present(group: str, filename: str) -> Path | None:
        file = root / group / filename
        require(not file.is_symlink(), "symlink refused: " + group + "/" + filename)
        return file if file.is_file() else None

    live = present("web", "live-integrity.json")
    browser = present("web", "playwright.json")
    # A half-supplied Web pair must be rejected, not quietly counted missing.
    if live or browser:
        live = root / "web/live-integrity.json"
        browser = root / "web/playwright.json"
    campaign = present("campaign", "campaign-session.json")
    evidence = argparse.Namespace(
        manifest=manifest_path,
        assets=REPO / "public/games/omega-3d-preview",
        game=REPO / "godot/empire-omega/scripts/mission_manager.gd",
        r50_live=live, r50_browser=browser,
        campaign=campaign, campaign_dir=root / "campaign" if campaign else None,
        android=present("android", "android.json"),
        ios=present("ios", "ios.json"),
        sessions=present("players", "twenty-sessions.json"),
        art=present("art", "art-review.json"),
    )
    verdict = r83.run(evidence)
    require(verdict.get("source_commit") == source and
            verdict.get("production_go") is False,
            "original R83 source and fail-closed decision mismatch")
    return verdict


def main() -> int:
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("action", choices=("init", "sessions", "audit"))
    p.add_argument("--root", required=True, type=Path,
                   help="ABSOLUTE private path outside Git checkout")
    p.add_argument("--manifest", type=Path, default=DEFAULT_MANIFEST)
    p.add_argument("--require-ready", action="store_true",
                   help="Only for audit; return failure while field evidence is HOLD")
    args = p.parse_args()
    try:
        if args.action == "init":
            result = initialize(args.root, args.manifest)
        elif args.action == "sessions":
            result = sessions(args.root, args.manifest)
        else:
            result = audit(args.root, args.manifest)
        print(json.dumps(result, ensure_ascii=False, indent=2))
        return 2 if args.action == "audit" and args.require_ready and \
            result["status"] != "READY_FOR_INDEPENDENT_HUMAN_SIGNOFF" else 0
    except (OSError, ValueError, TypeError, KeyError, OverflowError) as e:
        print(json.dumps({"status": "HOLD", "production_go": False,
                          "error": str(e)}, ensure_ascii=False), file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
