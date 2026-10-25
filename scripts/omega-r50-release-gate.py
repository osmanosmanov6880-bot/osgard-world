#!/usr/bin/env python3
"""EMPIRE Omega R50 evidence gate. NO deployment or claims of AAA / phone FPS.

Joins 7/7 real public byte attestation, live desktop+touch Playwright JSON and
self-reported physical phone material. Never infers source SHA from merge SHA.
Only an independent human reviewer can grant a final release sign-off.
"""
import argparse
import hashlib
import json
import re
import tempfile
from pathlib import Path

REQUIRED = {"index.html", "index.js", "index.wasm", "index.pck"}
PROJECTS = {"desktop-chromium", "touch-phone-chromium"}
SHA40 = re.compile(r"^[0-9a-f]{40}$")
SHA64 = re.compile(r"^[0-9a-f]{64}$")
SAFE_NAME = re.compile(r"^[A-Za-z0-9_.-]{1,128}$")


def require(ok, message):
    if not ok:
        raise ValueError(message)


def read_json(path):
    data = json.loads(Path(path).read_text(encoding="utf-8"))
    require(isinstance(data, dict), f"JSON object required: {path}")
    return data


def validate_manifest(manifest, root, strict_bytes=True):
    require(manifest.get("engine") == "Godot 4.4.1", "wrong engine")
    require(manifest.get("native_tests") == "passed", "native tests not attested")
    require(manifest.get("artifact_kind") == "native-Godot-HTML5-export", "fake Godot export")
    require(manifest.get("source_path") == "godot/empire-omega", "wrong game")
    source = str(manifest.get("source_commit", ""))
    require(bool(SHA40.fullmatch(source)), "missing exact source commit")
    files = manifest.get("files")
    require(isinstance(files, dict) and len(files) == 7 and REQUIRED <= set(files), "7 original binary assets required")
    for name, digest in files.items():
        require(bool(SAFE_NAME.fullmatch(str(name))) and name not in (".", ".."), "unsafe file path")
        require(bool(SHA64.fullmatch(str(digest))), f"invalid checksum for {name}")
        path = Path(root) / name
        require(path.is_file(), f"missing repository binary: {name}")
        if strict_bytes and name == "index.wasm":
            require(path.stat().st_size > 1000000, "missing real WebAssembly")
        if strict_bytes and name == "index.pck":
            require(path.stat().st_size > 100000, "missing real packed game")
        h = hashlib.sha256()
        with path.open("rb") as src:
            while chunk := src.read(262144):
                h.update(chunk)
        require(h.hexdigest() == digest, f"tampered binary: {name}")
    return source


def validate_live(report, manifest):
    names = set(manifest["files"])
    require(report.get("status") == "PASS", "independent live byte verification missing")
    require(report.get("source_commit") == manifest["source_commit"], "public Godot source SHA mismatch")
    require(report.get("verified_files") == 7, "public SHA-256 must match 7/7")
    items = report.get("results", [])
    require(isinstance(items, list) and len(items) == 7, "need seven independent downloaded files")
    require(all(isinstance(x, dict) for x in items), "malformed public byte evidence")
    require({x.get("file") for x in items} == names, "published file names differ")
    require(all(x.get("sha256") == "matched" and int(x.get("bytes", 0)) > 0 for x in items), "public byte mismatch")
    # The independent downloader emits the actual SHA-256 it calculated
    # from the HTTP response stream, not just an uninspectable 'matched' label.
    # Cross-check all seven concrete digests against the source manifest.
    require(all(x.get("computed_sha256") == manifest["files"][x["file"]] for x in items),
            "public measured SHA-256 evidence does not match source release.json")
    require(int(report.get("bytes", 0)) == sum(int(x["bytes"]) for x in items), "public byte aggregate inconsistent")
    return True


def collect_tests(node):
    tests = []
    if isinstance(node, dict):
        if "projectName" in node and "results" in node:
            tests.append(node)
        for value in node.values():
            tests.extend(collect_tests(value))
    elif isinstance(node, list):
        for value in node:
            tests.extend(collect_tests(value))
    return tests


def validate_browser(raw):
    require(isinstance(raw, dict), "real Playwright JSON report required")
    stats = raw.get("stats", {})
    require(isinstance(stats, dict) and int(stats.get("unexpected", -1)) == 0, "browser tests failed")
    tests = collect_tests(raw.get("suites", []))
    projects = set()
    for test in tests:
        name = test.get("projectName")
        results = test.get("results", [])
        require(isinstance(results, list) and results, f"missing browser results: {name}")
        # A previous failed attempt is not sufficient: final result must pass.
        require(results[-1].get("status") == "passed", f"failed live browser drive: {name}")
        if name in PROJECTS:
            projects.add(name)
    require(projects == PROJECTS, f"need exact desktop and touch projects: {projects}")
    # Playwright counts successful retries under 'flaky', not 'expected'.
    # Preserve final source-bound evidence but flag that instability for
    # separate manual release review; no flaky execution equals 100% stable.
    expected_count = int(stats.get("expected", 0))
    flaky_count = int(stats.get("flaky", 0))
    require(expected_count >= 0 and flaky_count >= 0, "invalid browser counts")
    require(expected_count + flaky_count >= 2, "not enough passed browser scenarios")
    return sorted(projects)


def validate_device_report(path, source):
    data = read_json(path)
    require(data.get("schema") == "empire-omega-r50-physical-v1", "unknown device schema")
    require(data.get("source_commit") == source, "device tested different game source SHA")
    kind = data.get("os_family")
    require(kind in ("android", "ios"), "physical device must identify Android or iOS")
    require(data.get("physical_device") is True, "emulator/browser runner is not a phone")
    for key in ("model", "os_version", "browser", "operator", "capture_utc"):
        require(isinstance(data.get(key), str) and len(data[key].strip()) >= 3, f"missing device metadata {key}")
    for key in ("warmup_s", "capture_s", "p95_frame_ms", "p99_frame_ms", "frame_count"):
        value = data.get(key)
        require(isinstance(value, (int, float)) and not isinstance(value, bool), f"missing {key}")
        require(float(value) > 0 and float(value) < 100000, f"invalid {key}")
    require(float(data["warmup_s"]) >= 2.0 and float(data["capture_s"]) >= 20.0, "insufficient real warmup/capture")
    require(int(data["frame_count"]) >= 100, "insufficient physical frames")
    require(float(data["p99_frame_ms"]) >= float(data["p95_frame_ms"]), "p99 better than p95")
    raw_capture = data.get("recording_file", "")
    require(isinstance(raw_capture, str) and bool(SAFE_NAME.fullmatch(raw_capture)), "unsafe or missing device recording")
    video = Path(path).parent / raw_capture
    require(video.is_file() and video.stat().st_size > 1024, "real device recording missing")
    digest = hashlib.sha256(video.read_bytes()).hexdigest()
    require(digest == data.get("recording_sha256"), "device recording SHA-256 mismatch")
    return kind


def build_verdict(manifest, asset_dir, live=None, browser=None, devices=None, strict_bytes=True):
    source = validate_manifest(manifest, asset_dir, strict_bytes)
    issues = []
    if live is None:
        issues.append("missing-live-public-sha256")
    else:
        validate_live(live, manifest)
    projects = []
    browser_flaky_tests = 0
    if browser is None:
        issues.append("missing-independent-live-desktop-touch")
    else:
        projects = validate_browser(browser)
        browser_flaky_tests = int(browser.get("stats", {}).get("flaky", 0))
        if browser_flaky_tests:
            issues.append("flaky-browser-retries-need-stability-rerun")
    hardware = []
    if devices:
        for file in sorted(devices):
            hardware.append(validate_device_report(file, source))
    if not {"android", "ios"} <= set(hardware):
        issues.append("missing-two-physical-hardware-reports")
    return {
        "schema": "omega-r50-release-evidence-v1",
        "source_commit": source,
        "repository_assets": 7,
        "public_verified_sha256": 7 if live is not None else 0,
        "live_chromium_projects": projects,
        "browser_flaky_tests": browser_flaky_tests,
        "reported_physical_os": sorted(set(hardware)),
        "status": "MANUAL_RELEASE_REVIEW_REQUIRED" if not issues else "HOLD",
        "gaps": issues,
        "aaa_quality_attested": False,
        "approval": "No automated workflow can certify physical devices, artwork quality or production business release."
    }


def self_test():
    with tempfile.TemporaryDirectory() as temporary:
        base = Path(temporary)
        files = {name: (name.encode() * 400) for name in
                 ("index.html", "index.js", "index.wasm", "index.pck",
                  "index.png", "index.audio.worklet.js", "index.audio.position.worklet.js")}
        for name, payload in files.items():
            (base / name).write_bytes(payload)
        manifest = {
            "engine": "Godot 4.4.1", "native_tests": "passed",
            "artifact_kind": "native-Godot-HTML5-export",
            "source_path": "godot/empire-omega", "source_commit": "a"*40,
            "files": {name: hashlib.sha256(body).hexdigest() for name, body in files.items()}
        }
        assert build_verdict(manifest, base, strict_bytes=False)["status"] == "HOLD"
        live = {"status": "PASS", "source_commit": "a"*40, "verified_files": 7,
                "results": [{"file": name, "sha256": "matched", "bytes": len(body),
                             "computed_sha256": manifest["files"][name]}
                            for name, body in files.items()],
                "bytes": sum(len(x) for x in files.values())}
        def test_entry(name):
            return {"projectName": name, "results": [{"status": "passed"}]}
        browser = {"stats": {"unexpected": 0, "expected": 2},
                   "suites": [{"tests": [test_entry(name) for name in PROJECTS]}]}
        assert build_verdict(manifest, base, live, browser, strict_bytes=False)["status"] == "HOLD"
        assert build_verdict(manifest, base, live, browser, strict_bytes=False)["public_verified_sha256"] == 7
        # R68 authentic report: desktop first capture timed out but passed
        # on retry, and mobile passed on the first attempt. The projects
        # still contain two real final PASS records and one flaky warning.
        recovered = json.loads(json.dumps(browser))
        recovered["stats"] = {"unexpected": 0, "expected": 1, "flaky": 1}
        recovered["suites"][0]["tests"][0]["results"] = [
            {"status": "failed"}, {"status": "passed"}
        ]
        assert validate_browser(recovered) == sorted(PROJECTS)
        reliability = build_verdict(manifest, base, live, recovered, strict_bytes=False)
        assert reliability["status"] == "HOLD"
        assert reliability["public_verified_sha256"] == 7
        assert reliability["browser_flaky_tests"] == 1
        assert "flaky-browser-retries-need-stability-rerun" in reliability["gaps"]
        assert "missing-independent-live-desktop-touch" not in reliability["gaps"]
        def reject(fn):
            try:
                fn()
            except ValueError:
                return
            raise AssertionError("R50 gate accepted invalid release evidence")
        mismatch = dict(live, source_commit="b"*40)
        reject(lambda: validate_live(mismatch, manifest))
        forged_digest = json.loads(json.dumps(live))
        forged_digest["results"][0]["computed_sha256"] = "0"*64
        reject(lambda: validate_live(forged_digest, manifest))
        no_digest = json.loads(json.dumps(live))
        no_digest["results"][0].pop("computed_sha256")
        reject(lambda: validate_live(no_digest, manifest))
        broken = json.loads(json.dumps(manifest))
        broken["files"]["index.js"] = "0"*64
        reject(lambda: validate_manifest(broken, base, False))
        browser_bad = json.loads(json.dumps(browser))
        browser_bad["suites"][0]["tests"][0]["results"][0]["status"] = "failed"
        reject(lambda: validate_browser(browser_bad))
        misleading_flaky = json.loads(json.dumps(recovered))
        misleading_flaky["stats"]["flaky"] = 0
        reject(lambda: validate_browser(misleading_flaky))
        retry_ended_failed = json.loads(json.dumps(recovered))
        retry_ended_failed["suites"][0]["tests"][0]["results"].append({"status": "failed"})
        reject(lambda: validate_browser(retry_ended_failed))
        fake_device = base / "phone.json"
        fake_device.write_text(json.dumps({"schema": "empire-omega-r50-physical-v1",
                                           "source_commit": "a"*40, "os_family": "android",
                                           "physical_device": False}))
        reject(lambda: validate_device_report(fake_device, "a"*40))
    print("PASS R50 evidence: exact hashes, real desktop+touch, flaky retry HOLD, fake hardware rejected")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--self-test", action="store_true")
    parser.add_argument("--manifest", default="public/games/omega-3d-preview/release.json")
    parser.add_argument("--assets", default="public/games/omega-3d-preview")
    parser.add_argument("--live-evidence")
    parser.add_argument("--browser-json")
    parser.add_argument("--device-dir")
    parser.add_argument("--output")
    args = parser.parse_args()
    if args.self_test:
        self_test()
        return
    data = read_json(args.manifest)
    live = read_json(args.live_evidence) if args.live_evidence else None
    browser = read_json(args.browser_json) if args.browser_json else None
    devices = list(Path(args.device_dir).glob("*.json")) if args.device_dir else []
    verdict = build_verdict(data, Path(args.assets), live, browser, devices)
    result = json.dumps(verdict, indent=2, ensure_ascii=False)
    if args.output:
        Path(args.output).write_text(result + "\n", encoding="utf-8")
    print(result)


if __name__ == "__main__":
    main()
