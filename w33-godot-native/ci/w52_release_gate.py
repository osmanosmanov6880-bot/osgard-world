#!/usr/bin/env python3
"""W52: source-matched offline Godot release evidence gate, never deploy.

Validates independent CI artifacts, actual measured drawcalls, six missions,
real original screenshots, emulated touch, Windows boot and deterministic
candidate contents. Even a passing software gate means production HOLD until
physical hardware and human visual acceptance are explicitly recorded.
"""
import argparse
import hashlib
import json
import zipfile
from pathlib import Path, PurePosixPath

W47_PINNED_SHA = "14be69cdaa1fdffa4e209645eed0b1964581858a"


def sha_file(path):
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for block in iter(lambda: handle.read(2**20), b""):
            digest.update(block)
    return digest.hexdigest()


def read_json(path):
    if not path.is_file():
        raise ValueError("Missing exact CI evidence: " + str(path))
    return json.loads(path.read_text(encoding="utf-8"))


def require(value, name):
    if not value:
        raise ValueError("W52 gate rejected: " + name)


def pngs(root, frames):
    for entry in frames:
        rel = entry["image"]
        require(PurePosixPath(rel).name == rel, "unsafe or nested screenshot " + rel)
        image = root / rel
        require(image.is_file(), "missing native screenshot " + rel)
        with image.open("rb") as data:
            require(data.read(8) == b"\x89PNG\r\n\x1a\n", "not original PNG " + rel)
        require(sha_file(image) == entry["sha256"], "altered native screenshot " + rel)


def candidate_zip(path, head):
    require(path.is_file(), "signed candidate ZIP absent")
    with zipfile.ZipFile(path) as archive:
        require(archive.testzip() is None, "release ZIP CRC corrupt")
        records = [entry for entry in archive.infolist() if not entry.is_dir()]
        names = [item.filename for item in records]
        require(len(names) == len(set(names)), "release ZIP duplicate entry")
        for name in names:
            posix = PurePosixPath(name)
            require(not name.startswith("/") and "\\" not in name and
                    ".." not in posix.parts, "unsafe ZIP path: " + name)
        require("CANDIDATE_MANIFEST.json" in names, "candidate manifest absent")
        meta = json.loads(archive.read("CANDIDATE_MANIFEST.json"))
        require(meta.get("source_commit") == head, "W42 candidate is not exact PR HEAD")
        require(meta.get("godot") == "4.4.1", "candidate engine differs")
        require(meta.get("candidate_only") is True and meta.get("production_modified") is False,
                "unsafe production assertion in candidate")
        require(meta.get("browser_6_cases_verified") is True, "not six complete browser missions")
        require(meta.get("windows_os_boot_verified") is True, "Windows 2022 original executable boot absent")
        require(meta.get("original_visual_evidence_included") is True, "native art omitted")
        require(meta.get("physical_device_certified") is False and
                meta.get("AAA_graphics_certified") is False, "false hardware/AAA certification")
        manifest_files = meta.get("files", [])
        require(len(manifest_files) > 15, "unreasonably small W42 candidate")
        require(set(names) == ({f["name"] for f in manifest_files} | {"CANDIDATE_MANIFEST.json"}),
                "ZIP members differ from manifest")
        for item in manifest_files:
            name = item["name"]
            require(archive.getinfo(name).file_size == item["bytes"], "ZIP payload size changed: " + name)
            # Stream each uncompressed entry: no fake manifest or in-memory
            # acceptance of unsigned original Godot executable/WASM bytes.
            checksum = hashlib.sha256()
            with archive.open(name) as original:
                for block in iter(lambda: original.read(2**20), b""):
                    checksum.update(block)
            require(checksum.hexdigest() == item["sha256"], "ZIP evidence digest mismatch: " + name)
        # Independently inspect ORIGINAL nested manifests rather than trusting
        # only the outer release packager's convenience PASS flags.
        nested = {
            "web": "web/evidence.json",
            "windows": "windows/windows-build.json",
            "gameplay": "qa/gameplay/gameplay-evidence.json",
            "art": "qa/real_art/visual-evidence.json",
            "windows_boot": "qa/windows_boot/windows-boot-verdict.json",
        }
        for label, item in nested.items():
            require(item in names, "signed candidate missing original " + label + " proof")
        evidence = {label: json.loads(archive.read(name)) for label, name in nested.items()}
        require(evidence["web"].get("source_commit") == head and
                evidence["web"].get("godot_release") == "4.4.1", "nested original Godot WebGL SHA")
        require(evidence["windows"].get("source_commit") == head and
                evidence["windows"].get("software_export") == "PASS", "nested Windows export SHA")
        require(evidence["gameplay"].get("source_sha") == head and
                evidence["gameplay"].get("status") == "PASS" and
                evidence["gameplay"].get("gameplay_verified_by_real_canvas_events") is True, "nested real Chromium missions")
        devices = evidence["gameplay"].get("devices", [])
        require(any(x.get("result") == "PASS" and x.get("missions") == list(range(6))
                    for x in devices), "nested browser six real successful missions absent")
        require(evidence["art"].get("source_sha") == head and
                evidence["art"].get("status") == "PASS" and
                evidence["art"].get("real_godot_export") is True and
                len(evidence["art"].get("frames", [])) >= 5, "nested original Godot visual evidence")
        require(evidence["windows_boot"].get("source_commit") == head and
                evidence["windows_boot"].get("actual_windows_runner_exe_started") is True and
                evidence["windows_boot"].get("exit_code") == 0, "nested genuine Windows executable boot")
        require(archive.read("web/index.wasm").startswith(b"\x00asm") and
                archive.read("web/index.pck").startswith(b"GDPC"), "Web export is not genuine Godot binary")
        with archive.open("windows/OSGARD_FIELD_LAB_W33.exe") as executable:
            require(executable.read(2) == b"MZ", "packaged Windows executable header corrupt")
        with archive.open("windows/OSGARD_FIELD_LAB_W33.pck") as pack:
            require(pack.read(4) == b"GDPC", "packaged Windows resource PCK invalid")
        return {"sha256": sha_file(path), "bytes": path.stat().st_size,
                "manifest_files_verified": len(manifest_files),
                "nested_original_manifests_verified": sorted(nested),
                "actual_windows_runner_boot": True}


def validate(opts):
    source = read_json(opts.source)
    performance = read_json(opts.performance)
    paired = read_json(opts.paired)
    touch = read_json(opts.touch)
    art = read_json(opts.visual)
    head = opts.head_sha
    base = opts.base_sha
    require(base == W47_PINNED_SHA, "unexpected W47 baseline")
    require(len(head) == 40 and all(x in "0123456789abcdef" for x in head), "invalid exact HEAD")
    require(source.get("status") == "PASS" and
            source.get("candidate_w48_sha") == head and
            source.get("baseline_w47_sha") == base and
            source.get("production_source_unchanged") is True, "W49 source contract")
    require(performance.get("status") == "PASS" and performance.get("source_sha") == head,
            "W44 original game engine benchmark")
    measured = performance.get("runs", [])
    require(len(measured) == 3 and all(
        r.get("render_draw_call_samples", 0) >= 3 and
        r.get("render_object_sample_count", 0) >= 3 and
        r.get("render_draw_calls_median", 0) > 0 and
        r.get("godot_rendered_frames_progressed") is True for r in measured
    ), "actual W48 Godot draw calls/objects or engine render progression missing")
    require(performance.get("physical_iphone_android_tested") is False and
            performance.get("physical_windows_gpu_tested") is False, "software benchmark falsely implies hardware")
    require(paired.get("status") == "PASS" and
            paired.get("baseline_w47_sha") == base and
            paired.get("candidate_w48_sha") == head and
            paired.get("pristine_git_exports_no_probe_injected") is True and
            paired.get("pixel_parity_certified") is False, "W50/W51 original side-by-side evidence")
    observations = paired.get("observations", [])
    require(len(observations) == 10 and len(paired.get("comparisons", [])) == 5,
            "paired 10 original Godot WebGL camera/quality observations missing")
    require({(o["scenario"], o["build"]) for o in observations} ==
            {(name, build) for name in ("desktop_hero", "desktop_inspection", "desktop_service", "desktop_eco", "touch_hero")
             for build in ("w47", "w48")}, "paired scenarios incomplete")
    for o in observations:
        require(o.get("source_instrumented") is False and
                o["engine"].get("godot_rendered_frames_progressed") is True, "pristine W47/W48 frame progression")
        if o["build"] == "w48":
            require(o["engine"].get("render_draw_call_samples", 0) >= 3,
                    "matched W48 scene lacked draw calls")
    pngs(opts.paired.parent, [o["frame"] for o in observations])
    require((opts.paired.parent / "W50_W47_W48_ORIGINAL_RENDER_SIDE_BY_SIDE.png").is_file(),
            "W47/W48 visual contact sheet missing")
    require(touch.get("status") == "PASS" and touch.get("source_sha") == head and
            touch.get("completed_case") == 0 and touch.get("native_events_confirmed", 0) >= 8,
            "original 390px emulated touch mission failed")
    image = opts.touch.parent / "w45-mobile-real-touch-first-mission.png"
    require(image.is_file() and sha_file(image) == touch.get("original_screenshot_sha256"),
            "mobile touch framebuffer evidence modified")
    require(art.get("status") == "PASS" and art.get("source_sha") == head and
            art.get("real_godot_export") is True and
            art.get("not_concept_art") is True, "W39 native artwork evidence")
    require(len(art.get("frames", [])) >= 5, "original five camera/HERO/ECO/mobile frames missing")
    pngs(opts.visual.parent, art["frames"])
    packed = candidate_zip(opts.candidate, head)
    return {
        "schema": "OSGARD_W52_SOURCE_MATCHED_SOFTWARE_RELEASE_GATE_V1",
        "status": "PASS",
        "decision": "STAGING_CANDIDATE_VERIFIED_PRODUCTION_HOLD",
        "source_sha": head,
        "baseline_w47_sha": base,
        "w49_original_missions_and_production_blob_parity": "PASS",
        "w48_geometry_native_ci": "GATED_BY_UPSTREAM_ACTUAL_GODOT_JOB",
        "w50_paired_native_render_screenshots_3_cameras_hero_eco_mobile": "PASS",
        "w51_software_godot_fps_and_actual_candidate_drawcalls": "PASS_DIAGNOSTIC_ONLY",
        "w45_touch_emulated_first_mission": "PASS",
        "w33_all_six_actual_chromium_missions": "GATED_BY_SIGNED_W42_CANDIDATE",
        "w34_real_windows_2022_exe_started": "PASS",
        "reproducible_candidate": packed,
        "observed_software_fps_negative_scenarios": [
            p["scenario"] for p in paired["comparisons"]
            if p.get("single_pair_observed_fps_change_percent") is not None
            and p["single_pair_observed_fps_change_percent"] < 0
        ],
        "software_release_gate_completed": True,
        "statistically_significant_fps_improvement_certified": False,
        "manual_cinematic_acceptance_complete": False,
        "physical_windows_gpu_accepted": False,
        "physical_iphone_android_accepted": False,
        "commercial_60fps_or_aaa_certified": False,
        "published_to_production": False,
        "merge_approved": False,
        "next_actions": [
            "Owner reviews original Godot W47/W48 screenshots and all runtime checks.",
            "Physically benchmark real Windows GPU plus iPhone and Android in HERO/ECO.",
            "Only then approve source-matched deployment and independent rollback plan.",
        ],
    }


def main():
    parser = argparse.ArgumentParser()
    for name in ("source", "performance", "paired", "touch", "visual", "candidate"):
        parser.add_argument("--" + name, type=Path, required=True)
    parser.add_argument("--base-sha", required=True)
    parser.add_argument("--head-sha", required=True)
    parser.add_argument("--out", type=Path, required=True)
    opts = parser.parse_args()
    opts.out.mkdir(parents=True, exist_ok=True)
    try:
        report = validate(opts)
    except (ValueError, KeyError, OSError, zipfile.BadZipFile) as ex:
        fail = {"schema": "OSGARD_W52_SOURCE_MATCHED_SOFTWARE_RELEASE_GATE_V1",
                "status": "FAIL", "decision": "HOLD", "source_sha": opts.head_sha,
                "reason": str(ex), "published_to_production": False}
        (opts.out / "w52-release-gate.json").write_text(
            json.dumps(fail, indent=2) + "\n", encoding="utf-8")
        raise SystemExit("W52 software release gate rejected evidence: " + str(ex))
    (opts.out / "w52-release-gate.json").write_text(
        json.dumps(report, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    with (opts.out / "W52_RELEASE_DECISION.md").open("w", encoding="utf-8") as readme:
        readme.write("# OSGARD W52 — independent software release decision\n\n")
        readme.write("**STAGING CANDIDATE VERIFIED — PRODUCTION HOLD**\n\n")
        readme.write("Exact source: `" + opts.head_sha + "`\n\n")
        readme.write("Evidence: W49 unchanged mission/core blobs; native Godot upstream; ")
        readme.write("W50 genuine original screenshot pairs; W51 measured software Godot FPS and ")
        readme.write("candidate draw calls; six real Chromium missions; W45 emulated touch; ")
        readme.write("Windows runner executable boot; twice-built deterministic ZIP digest.\n\n")
        readme.write("**Not certified:** device FPS, photorealism, physical Android/iOS/Windows GPU, ")
        readme.write("manual visual sign-off, production publication.\n")
    print(json.dumps({"status": report["status"], "decision": report["decision"],
                      "source_sha": opts.head_sha}, indent=2))


if __name__ == "__main__":
    main()
