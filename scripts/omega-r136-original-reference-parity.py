#!/usr/bin/env python3
"""R136: private source-locked original-art vs REAL Godot frame intake.

Requires TWO unchanged user-approved original image files and TWO original
Playwright/Godot PNG frames from a source-bound GitHub Actions artifact.
Never synthesizes reference art, rates AAA quality, or authorizes a deploy.
"""
from __future__ import annotations

import argparse
import hashlib
import html
import json
import os
import re
import stat
import struct
import sys
import zipfile
from pathlib import Path

import omega_r73_field_qa as original_png

REPO = Path(__file__).resolve().parent.parent
SCHEMA = "empire-omega-r136-art-originals-private-v1"
SHA40 = re.compile(r"[0-9a-f]{40}")
PNG_MEMBER = re.compile(r"omega-r90-report/data/[0-9a-f]{40}\.png")
SHA_LINE = "omega-r109-evidence/exact-tested-checkout.txt"
MAX_IMAGE = 16 * 1024 * 1024
MAX_ZIP_CONTENT = 80 * 1024 * 1024
FRAME_LABELS = ("world", "cabinet")


def require(ok: bool, why: str) -> None:
    if not ok:
        raise ValueError(why)


def sha256(raw: bytes) -> str:
    return hashlib.sha256(raw).hexdigest()


def real_file(path: Path) -> bytes:
    require(path.is_file() and not path.is_symlink(),
            "original image must be a real, existing regular file: " + path.name)
    require(100 <= path.stat().st_size <= MAX_IMAGE, "original image empty/oversized")
    return path.read_bytes()


def image_info(raw: bytes, name: str) -> tuple[str, int, int]:
    if raw.startswith(b"\x89PNG\r\n\x1a\n"):
        require(len(raw) >= 33 and raw[12:16] == b"IHDR", "corrupt original PNG")
        w, h = struct.unpack(">II", raw[16:24])
        kind = "png"
    elif raw[:3] == b"\xff\xd8\xff" and raw[-2:] == b"\xff\xd9":
        # Accept JPEG originals WITHOUT transcoding or modifying user art.
        # Scan SOF markers; a separate human must still inspect actual decoding.
        index = 2
        w = h = 0
        while index + 4 < len(raw):
            if raw[index] != 0xFF:
                index += 1
                continue
            while index < len(raw) and raw[index] == 0xFF:
                index += 1
            if index >= len(raw):
                break
            mark = raw[index]
            index += 1
            if mark in (0xD8, 0xD9, 0x01) or 0xD0 <= mark <= 0xD7:
                continue
            if mark == 0xDA:
                break
            require(index + 2 <= len(raw), "truncated JPEG segment")
            length = struct.unpack(">H", raw[index:index + 2])[0]
            require(length >= 2 and index + length <= len(raw), "unsafe JPEG segment")
            if mark in (0xC0, 0xC1, 0xC2, 0xC3, 0xC5, 0xC6, 0xC7, 0xC9, 0xCA):
                require(length >= 7, "incomplete JPEG frame header")
                h, w = struct.unpack(">HH", raw[index + 3:index + 7])
                break
            index += length
        kind = "jpg"
    else:
        raise ValueError("unsupported ORIGINAL image: PNG or JPEG only: " + name)
    require(320 <= w <= 8192 and 240 <= h <= 8192, "invalid original dimensions")
    return kind, w, h


def safe_private_root(root: Path, creating: bool) -> Path:
    require(root.is_absolute() and not root.is_symlink(), "absolute non-symlink root required")
    require(root.resolve() != REPO.resolve() and not root.resolve().is_relative_to(REPO.resolve()),
            "original user references MUST stay outside GitHub/repository")
    require(root.parent.is_dir() and not root.parent.is_symlink(), "unsafe parent folder")
    if creating:
        require(not root.exists(), "private workspace exists: refuse replacement")
    else:
        require(root.is_dir(), "private workspace missing")
        if os.name == "posix":
            require(stat.S_IMODE(root.stat().st_mode) & 0o077 == 0,
                    "private root must be chmod 700")
    return root


def zip_frames(artifact: Path, world_name: str | None = None,
               cabinet_name: str | None = None) -> tuple[str, dict[str, bytes]]:
    require(artifact.is_file() and not artifact.is_symlink(), "missing real CI ZIP")
    require(artifact.stat().st_size <= MAX_ZIP_CONTENT, "CI ZIP unexpectedly huge")
    with zipfile.ZipFile(artifact, "r") as zipfile_obj:
        items = zipfile_obj.infolist()
        require(len(items) <= 250 and len({x.filename for x in items}) == len(items),
                "duplicate/oversized artifact entries")
        require(all(x.file_size <= MAX_IMAGE and
                    not x.filename.startswith("/") and
                    ".." not in x.filename.split("/")
                    for x in items), "unsafe zip name or decompression size")
        require(SHA_LINE in zipfile_obj.namelist(), "missing exact tested checkout SHA")
        sha_raw = zipfile_obj.read(SHA_LINE)
        value = sha_raw.decode("ascii").strip()
        require(bool(SHA40.fullmatch(value)), "missing original 40-digit source SHA")
        names = [x.filename for x in items if PNG_MEMBER.fullmatch(x.filename)]
        require(len(names) >= 2, "original real Godot PNG evidence missing")
        if world_name is None or cabinet_name is None:
            return value, {name: b"" for name in names}
        require(world_name in names and cabinet_name in names and world_name != cabinet_name,
                "choose two DISTINCT original source-bound Playwright screenshots")
        result: dict[str, bytes] = {}
        for role, name in (("world", world_name), ("cabinet", cabinet_name)):
            raw = zipfile_obj.read(name)
            require(len(raw) <= MAX_IMAGE and image_info(raw, name)[0] == "png",
                    "actual Godot screenshot must be authentic bounded PNG")
            result[role] = raw
        require(result["world"] != result["cabinet"], "duplicate actual render frames")
        return value, result


def locked_write(path: Path, data: bytes) -> None:
    fd = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
    with os.fdopen(fd, "wb") as out:
        out.write(data)


def markup(entries: list[dict]) -> str:
    cards = []
    for entry in entries:
        role = entry["role"]
        ref = entry["reference"]
        actual = entry["actual"]
        cards.append(
            '<section><h2>' + html.escape(role.upper()) + ' — original vs real Godot</h2>'
            '<div class="images"><figure><img src="reference-' + role + '.' +
            ref["extension"] + '"><figcaption>ORIGINAL USER REFERENCE · SHA ' +
            ref["sha256"][:16] + '</figcaption></figure>'
            '<figure><img src="actual-' + role + '.png"><figcaption>ACTUAL GODOT '
            'WEBGL · SHA ' + actual["sha256"][:16] + '</figcaption></figure></div>'
            '<label>Crossfade actual over original <input type="range" '
            'min="0" max="100" value="50" aria-label="Image comparison"></label>'
            '<div class="compare"><img class="reference" src="reference-' + role +
            '.' + ref["extension"] + '"><img class="actual" '
            'style="opacity:.50" src="actual-' + role + '.png"></div>'
            '<p class="hold">HOLD — mismatched camera framing/lighting is '
            'NOT an automatic AAA similarity score. Independent human art '
            'review required.</p></section>'
        )
    return (
        '<!doctype html><html lang="ru"><meta charset="utf-8">'
        '<meta name="referrer" content="no-referrer"><meta name="robots" content="noindex,nofollow">'
        '<meta http-equiv="Content-Security-Policy" content="default-src \'none\'; img-src \'self\' data:; '
        'style-src \'unsafe-inline\'; script-src \'unsafe-inline\'; form-action \'none\'; connect-src \'none\'">'
        '<meta name="viewport" content="width=device-width,initial-scale=1">'
        '<title>EMPIRE Ω · ORIGINAL ART HOLD</title><style>'
        'body{background:#10151b;color:#e5e6df;font-family:system-ui,sans-serif;'
        'max-width:1300px;margin:auto;padding:20px}h1{font-size:25px}h2{font-size:18px;'
        'color:#c8b58b;margin-top:35px}.images{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));'
        'gap:16px}figure{margin:0}figure img{width:100%;max-height:490px;object-fit:contain;'
        'background:#171e26}figcaption{font-size:12px;color:#a4adb4;overflow-wrap:anywhere}'
        '.compare{position:relative;width:100%;height:470px;background:#131923;'
        'overflow:hidden}.compare img{width:100%;height:100%;object-fit:contain;'
        'position:absolute;inset:0}.images img{min-height:180px}'
        'input{width:100%}.hold{font-size:13px;color:#d6bfa3}'
        '@media(max-width:650px){.images{grid-template-columns:1fr}.compare{height:300px}}'
        '</style><body><h1>EMPIRE Ω — source-locked visual reference comparison</h1>'
        '<p><strong>ART HOLD:</strong> original files are never generated, '
        'changed, uploaded or automatically approved. Compare composition, '
        'building massing, road/lighting, human/vehicle detail and HUD.</p>'
        + "".join(cards)
        + '<script>for(const section of document.querySelectorAll("section")){'
          'const slider=section.querySelector("input"),target=section.querySelector(".actual");'
          'slider.addEventListener("input",()=>target.style.opacity=(Number(slider.value)/100).toFixed(2));'
          '}</script></body></html>'
    )


def prepare(args: argparse.Namespace) -> dict:
    root = safe_private_root(Path(args.root), creating=True)
    source, actual = zip_frames(Path(args.browser_zip), args.world_frame, args.cabinet_frame)
    require(args.sha == source, "game SHA must equal actual tested GitHub browser frame SHA")
    require(args.run_id > 0 and args.artifact_id > 0, "GitHub evidence run/artifact IDs required")
    originals: dict[str, bytes] = {}
    for role in FRAME_LABELS:
        file = Path(getattr(args, role + "_reference"))
        originals[role] = real_file(file)
        image_info(originals[role], file.name)
        # Reference SHA is supplied INDEPENDENTLY by the reviewer, rather
        # than invented from whichever image somebody happened to select.
        expected = getattr(args, role + "_approved_sha256")
        require(re.fullmatch(r"[0-9a-f]{64}", expected) is not None,
                "a real prior approved 64-digit reference checksum is required")
        require(sha256(originals[role]) == expected,
                "selected original image DOES NOT MATCH approved reference SHA: " + role)
        require(originals[role] != actual[role], "reference cannot be actual game screenshot")
    require(originals["world"] != originals["cabinet"], "two different ORIGINAL references required")
    data = []
    for role in FRAME_LABELS:
        ext, rw, rh = image_info(originals[role], role)
        _, aw, ah = image_info(actual[role], role + " Godot")
        data.append({
            "role": role,
            "reference": {"path": "reference-" + role + "." + ext, "sha256": sha256(originals[role]),
                          "extension": ext, "size": [rw, rh]},
            "actual": {"path": "actual-" + role + ".png", "sha256": sha256(actual[role]),
                       "source_member": getattr(args, role + "_frame"), "size": [aw, ah]},
        })
    manifest = {
        "schema": SCHEMA, "source_sha": source,
        "github_run_id_claim": args.run_id, "github_artifact_id_claim": args.artifact_id,
        "github_identity_independently_verified": False,
        "reference_sha_user_asserted_matches_selected_bytes": True,
        "independent_reference_identity_approval_verified": False,
        "pairs": data, "original_references_provided": True,
        "reviewer_signed": False, "aaa_art_approved": False,
        "physical_hardware_approved": False, "human_playthroughs_approved": False,
        "rollback_staging_approved": False, "production_authorized": False,
    }
    root.mkdir(mode=0o700)
    try:
        for entry in data:
            role = entry["role"]
            locked_write(root / entry["reference"]["path"], originals[role])
            locked_write(root / entry["actual"]["path"], actual[role])
        locked_write(root / "manifest.json", (json.dumps(manifest, indent=2, ensure_ascii=False)+"\n").encode())
        locked_write(root / "comparison.html", markup(data).encode("utf-8"))
        locked_write(root / "review.template.json", (json.dumps({
            "schema": "empire-omega-r136-human-art-review-v1", "source_sha": source,
            "reviewer_name": "", "reviewed_on_utc": "", "independent_review": False,
            "world": {"verdict": "PENDING", "differences": ["building/road/car/lighting vs original"]},
            "cabinet": {"verdict": "PENDING", "differences": ["HUD/fonts/real World3D vs original"]},
            "originals_compared": False, "actual_godot_frames_compared": False,
            "notice": "Template; not a signature, not production GO."
        }, indent=2, ensure_ascii=False)+"\n").encode())
    except BaseException:
        # A half-built private workspace is never accepted by audit.
        raise
    return {"status": "ART_EVIDENCE_CREATED_REVIEW_REQUIRED",
            "source_sha": source, "pairs": len(data), "production_authorized": False,
            "private_directory": str(root), "browser_gallery": "comparison.html"}


def audit(root: Path) -> dict:
    safe_private_root(root, creating=False)
    manifest_path = root / "manifest.json"
    require(not manifest_path.is_symlink(), "linked manifest forbidden")
    manifest = json.loads(manifest_path.read_text("utf-8"))
    require(manifest.get("schema") == SCHEMA and not manifest.get("production_authorized"),
            "invalid or modified production flag")
    require(SHA40.fullmatch(str(manifest.get("source_sha", ""))) is not None,
            "invalid original source SHA")
    pairs = manifest.get("pairs", [])
    require(isinstance(pairs, list) and len(pairs) == 2 and
            [p.get("role") for p in pairs] == ["world", "cabinet"], "both roles required")
    for entry in pairs:
        for key in ("reference", "actual"):
            image = entry[key]
            filename = image["path"]
            require(re.fullmatch(r"(reference|actual)-(world|cabinet)\.(png|jpg)", filename)
                    is not None, "unsafe original art path")
            path = root / filename
            body = real_file(path)
            require(sha256(body) == image["sha256"], "source image modified: " + filename)
            kind, w, h = image_info(body, filename)
            require([w,h] == image["size"], "original image size mismatch")
            require(kind == filename.split(".")[-1], "original MIME/ext mismatch")
            if kind == "png":
                original_png.validate_decodable_png(path)
    result = {"source_sha":manifest["source_sha"],
              "status":"REFERENCE_INTEGRITY_PASS_HUMAN_REVIEW_HOLD",
              "original_pairs":2, "originals_unchanged":True,
              "independent_original_art_review_verified":False,
              "physical_36_hardware_trials_verified":False,
              "human_gameplay_verified":False,
              "production_authorized":False}
    return result


def main() -> int:
    p=argparse.ArgumentParser(description=__doc__)
    sub=p.add_subparsers(dest="command",required=True)
    view=sub.add_parser("inspect",help="List original source-locked GitHub browser PNGs")
    view.add_argument("--browser-zip",required=True)
    prep=sub.add_parser("prepare",help="Create private 2-reference/2-Godot comparison")
    for flag in ("root","sha","browser-zip","world-frame","cabinet-frame",
                 "world-reference","cabinet-reference",
                 "world-approved-sha256","cabinet-approved-sha256"):
        prep.add_argument("--"+flag,required=True)
    prep.add_argument("--run-id",type=int,required=True)
    prep.add_argument("--artifact-id",type=int,required=True)
    review=sub.add_parser("audit",help="Verify original immutable art, never approve production")
    review.add_argument("--root",required=True)
    args=p.parse_args()
    try:
        if args.command=="inspect":
            source,names=zip_frames(Path(args.browser_zip))
            print(json.dumps({"source_sha":source,"source_locked_png_members":list(names)},indent=2))
        elif args.command=="prepare":
            require(bool(SHA40.fullmatch(args.sha)),"exact 40-digit original SHA required")
            print(json.dumps(prepare(args),indent=2,ensure_ascii=False))
        else:
            print(json.dumps(audit(Path(args.root)),indent=2,ensure_ascii=False))
    except (ValueError, OSError, KeyError, zipfile.BadZipFile, UnicodeError) as exc:
        print(json.dumps({"status":"HOLD","production_authorized":False,"reason":str(exc)},
                         ensure_ascii=False),file=sys.stderr)
        return 1
    return 0


if __name__=="__main__":
    raise SystemExit(main())
