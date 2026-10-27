#!/usr/bin/env python3
"""Deterministic, source-attested LAST FRONTIER software-preview packager.

The new player-facing name is an *uncleared working title*. This tool never
performs publication or transforms CI/software evidence into device/market GO.
"""
import argparse
import hashlib
import json
import re
import stat
import struct
import zipfile
from pathlib import Path, PurePosixPath

SCHEMA = "LAST_FRONTIER_W62_OFFLINE_REVIEW_PACKAGE_V1"
README = """ПОСЛЕДНИЙ РУБЕЖ / LAST FRONTIER — ПРОТОТИП.
Рабочее название: юридическая проверка не завершена.
Шесть офлайн-миссий диагностики; НЕ инструкция для реального оборудования.
Windows: распакуйте Windows/LAST_FRONTIER.exe и LAST_FRONTIER.pck вместе.
Browser: откройте Web/index.html через локальный HTTP-сервер.
Это только тестовая сборка. Аппаратные испытания и коммерческий выпуск не утверждены.
"""
REQUIRED_WEB = ("index.html", "index.js", "index.wasm", "index.pck")


class Reject(ValueError):
    pass


def require(condition, message):
    if not condition:
        raise Reject(message)


def digest(data):
    return hashlib.sha256(data).hexdigest()


def read_bytes(path, max_size=300_000_000):
    require(path.is_file() and not path.is_symlink(), "Missing or symlink: " + str(path))
    require(0 < path.stat().st_size <= max_size, "Invalid file size: " + str(path))
    return path.read_bytes()


def safe_members(root):
    require(root.is_dir() and not root.is_symlink(), "Missing exported directory")
    entries = []
    for path in sorted(root.rglob("*")):
        require(not path.is_symlink(), "Symlinks forbidden: " + str(path))
        if path.is_dir():
            continue
        require(path.is_file(), "Unexpected non-file in export: " + str(path))
        rel = path.relative_to(root).as_posix()
        safe_rel(rel)
        entries.append((rel, read_bytes(path)))
    return entries


def safe_rel(rel):
    require(isinstance(rel, str) and rel and "\\" not in rel and not rel.startswith("/"),
            "Unsafe archive member")
    p = PurePosixPath(rel)
    require(not p.is_absolute() and all(part not in ("", ".", "..") for part in p.parts),
            "Unsafe archive member: " + rel)
    require(":" not in rel, "Unsafe archive member: " + rel)
    return rel


def verify_web(directory, source):
    listed = dict(safe_members(directory))
    require(all(x in listed for x in REQUIRED_WEB), "Incomplete real Godot Web export")
    require(len(listed["index.html"]) > 220 and b"<canvas" in listed["index.html"].lower(),
            "Not actual Godot HTML canvas")
    require(len(listed["index.js"]) > 1024, "Missing Godot Web runtime")
    require(len(listed["index.wasm"]) > 100_000 and listed["index.wasm"][:4] == b"\0asm",
            "Invalid Godot WebAssembly module")
    require(len(listed["index.pck"]) > 4096 and listed["index.pck"][:4] == b"GDPC",
            "Invalid Godot Web PCK")
    require("evidence.json" in listed, "Missing independent Godot export bytes report")
    meta = json.loads(listed["evidence.json"])
    require(meta.get("source_commit") == source and meta.get("godot_release") == "4.4.1",
            "Godot Web export report belongs to stale source")
    require(meta.get("software_only") is True and meta.get("physical_phone_verified") is False,
            "Web report falsely certifies physical devices")
    for item in meta.get("files", []):
        name = item["name"]
        safe_rel(name)
        require(name in listed and len(listed[name]) == item["bytes"] and
                digest(listed[name]) == item["sha256"],
                "Original Web byte manifest mismatch: " + name)
    require(len(meta.get("files", [])) >= 4, "Web proof lacks actual export files")
    return listed


def verify_windows(directory, source):
    listed = dict(safe_members(directory))
    names = {"LAST_FRONTIER.exe", "LAST_FRONTIER.pck", "windows-build.json"}
    require(names.issubset(listed), "Missing matching LAST_FRONTIER Windows EXE/PCK/manifest")
    exe = listed["LAST_FRONTIER.exe"]
    pck = listed["LAST_FRONTIER.pck"]
    require(len(exe) > 3_000_000 and exe[:2] == b"MZ", "Not a real Windows EXE")
    offset = struct.unpack_from("<I", exe, 60)[0]
    require(60 < offset < len(exe)-25 and exe[offset:offset+4] == b"PE\0\0",
            "Windows EXE missing genuine PE signature")
    machine = struct.unpack_from("<H", exe, offset + 4)[0]
    require(machine == 0x8664, "Windows EXE is not x64")
    require(len(pck) > 20_000 and pck[:4] == b"GDPC", "Invalid Godot Windows PCK")
    meta = json.loads(listed["windows-build.json"])
    require(meta.get("schema") == "LAST_FRONTIER_W62_WINDOWS_SOURCE_V1" and
            meta.get("source_commit") == source and meta.get("godot") == "4.4.1",
            "Windows build is not source-attested")
    require(meta.get("physical_gpu_certified") is False and
            meta.get("real_windows_boot_verified") is False,
            "Cross-build cannot self-certify device boot or GPU")
    for name in ("LAST_FRONTIER.exe", "LAST_FRONTIER.pck"):
        item = meta.get("files", {}).get(name, {})
        require(item.get("sha256") == digest(listed[name]) and
                item.get("bytes") == len(listed[name]),
                "Windows build byte attestation mismatch: " + name)
    return listed


def add(zf, name, data):
    safe_rel(name)
    info = zipfile.ZipInfo(name, date_time=(1980,1,1,0,0,0))
    info.compress_type = zipfile.ZIP_DEFLATED
    info.external_attr = 0o644 << 16
    info.create_system = 3
    zf.writestr(info, data, compress_type=zipfile.ZIP_DEFLATED, compresslevel=9)


def package(web, windows, source, output):
    require(re.fullmatch(r"[0-9a-f]{40}", source or "") is not None,
            "Expected full exact lowercase 40-character source SHA")
    output.mkdir(parents=True, exist_ok=True)
    web_files = verify_web(web, source)
    windows_files = verify_windows(windows, source)
    members = {"Web/" + name: data for name, data in web_files.items()}
    members.update({"Windows/" + name: data for name, data in windows_files.items()})
    members["READ_ME_FIRST_RU.txt"] = README.encode("utf-8")
    inventory = [{"name": name, "bytes": len(data), "sha256": digest(data)}
                 for name, data in sorted(members.items())]
    manifest = {
        "schema": SCHEMA, "source_commit": source, "engine": "Godot 4.4.1",
        "working_title_en": "LAST FRONTIER",
        "working_title_ru": "ПОСЛЕДНИЙ РУБЕЖ",
        "software_preview_only": True, "six_mission_qa_claim_from_package": False,
        "signed_by_human": False, "commercial_title_cleared": False,
        "physical_device_certified": False, "hardware_60fps_certified": False,
        "production_approved": False, "allow_master_merge": False,
        "production_deployed": False, "files": inventory,
    }
    manifest_bytes = (json.dumps(manifest, ensure_ascii=False, indent=2, sort_keys=True) + "\n").encode("utf-8")
    filename = "LAST_FRONTIER_REVIEW_" + source[:12] + ".zip"
    archive = output / filename
    with zipfile.ZipFile(archive, "w") as zf:
        for name, data in sorted(members.items()):
            add(zf, name, data)
        add(zf, "CANDIDATE_MANIFEST.json", manifest_bytes)
    result = verify_archive(archive, source)
    (output / "SHA256SUMS.txt").write_text(result["sha256"] + "  " + filename + "\n")
    (output / "build-report.json").write_text(json.dumps(result, indent=2, sort_keys=True) + "\n")
    return result


def verify_archive(archive, source):
    require(archive.name == "LAST_FRONTIER_REVIEW_" + source[:12] + ".zip",
            "Unexpected source-bound candidate filename")
    with zipfile.ZipFile(archive) as zf:
        require(zf.testzip() is None, "Corrupt archive CRC")
        files = [i for i in zf.infolist() if not i.is_dir()]
        names = [i.filename for i in files]
        require(len(names) == len(set(names)), "Duplicate archive members")
        for name in names:
            safe_rel(name)
        require("CANDIDATE_MANIFEST.json" in names, "No release evidence manifest")
        meta = json.loads(zf.read("CANDIDATE_MANIFEST.json"))
        require(meta.get("schema") == SCHEMA and meta.get("source_commit") == source,
                "Wrong inner manifest or source SHA")
        for key in ("software_preview_only",):
            require(meta.get(key) is True, "Must remain a software preview")
        for key in ("signed_by_human", "commercial_title_cleared",
                    "physical_device_certified", "hardware_60fps_certified",
                    "production_approved", "allow_master_merge", "production_deployed",
                    "six_mission_qa_claim_from_package"):
            require(meta.get(key) is False, "Forged production evidence flag: " + key)
        manifest_files = meta.get("files", [])
        require(len(manifest_files) > 8, "Candidate missing a real Web+Windows game")
        require({m["name"] for m in manifest_files} | {"CANDIDATE_MANIFEST.json"} == set(names),
                "Archive manifest does not match entries")
        for item in manifest_files:
            name = item["name"]
            safe_rel(name)
            info = zf.getinfo(name)
            require(info.file_size == item["bytes"], "Incorrect byte size " + name)
            with zf.open(name) as stream:
                h=hashlib.sha256()
                for block in iter(lambda: stream.read(1024*1024), b""):
                    h.update(block)
                require(h.hexdigest() == item["sha256"], "Archive tampered: " + name)
        require(zf.read("Windows/LAST_FRONTIER.exe")[:2] == b"MZ",
                "Windows EXE magic lost")
        require(zf.read("Web/index.wasm")[:4] == b"\0asm",
                "WebAssembly magic lost")
        return {
            "schema": "LAST_FRONTIER_W62_SOURCE_BOUND_ARCHIVE_CHECK_V1",
            "status": "PASS", "source_sha": source,
            "file": archive.name, "sha256": digest(read_bytes(archive)),
            "size_bytes": archive.stat().st_size, "verified_members": len(manifest_files),
            "real_hardware_certified": False, "commercial_name_cleared": False,
            "production_approved": False, "published": False,
        }


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--source-sha", required=True)
    p.add_argument("--web-dir", type=Path, required=True)
    p.add_argument("--windows-dir", type=Path, required=True)
    p.add_argument("--output-dir", type=Path, required=True)
    opts = p.parse_args()
    report = package(opts.web_dir, opts.windows_dir, opts.source_sha, opts.output_dir)
    print("ORIGINAL SOURCE-ATTESTED SOFTWARE ZIP PASS / PRODUCTION HOLD")
    print(report["file"], report["sha256"])


if __name__ == "__main__":
    main()
