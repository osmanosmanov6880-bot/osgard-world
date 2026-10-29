#!/usr/bin/env python3
"""G5 offline release security, rollback and reproducibility tests.

All fixture files/SHAs are SYNTHETIC TEST INPUTS. They are not claimed to
be Godot binaries, physical-device QA or a production release.
The CI separately packages and verifies actual exported Windows + WebGL.
"""
from __future__ import annotations

import hashlib
import json
import shutil
import stat
import tempfile
import unittest
import warnings
import zipfile
from pathlib import Path

import release_vault_g5 as vault


def payload_sha(contents: bytes) -> str:
    return hashlib.sha256(contents).hexdigest()


def fixture(root: Path, sha: str) -> tuple[Path, Path, Path, Path]:
    base = root / ("fixture-" + sha[:10])
    site, web, windows, proof = (
        base / "world-preview", base / "web", base / "windows", base / "proof"
    )
    for directory in (site, web, windows, proof):
        directory.mkdir(parents=True, exist_ok=True)
    for name in vault.SITE_CORE:
        file = site / name
        file.parent.mkdir(parents=True, exist_ok=True)
        if name == "assets/build-proof.json":
            continue
        if name == "play/index.wasm":
            data = b"\0asm" + b"G4_SYNTHETIC_FIXTURE" * 65000
        elif name == "play/index.pck":
            data = b"GDPC" + b"PCK_FIXTURE" * 1000
        elif name == "assets/gameplay-proof.png":
            data = b"\x89PNG\r\n\x1a\n" + b"LOCAL_TEST_CAPTURE" * 100
        elif name == "play/index.js":
            data = b"// synthetic JS test fixture, not executable game\n"
        else:
            data = (name + "|" + sha + "\n").encode() * 2
        file.write_bytes(data)
    for name in ("index.html", "index.js", "index.wasm", "index.pck"):
        shutil.copyfile(site / "play" / name, web / name)
    exe = windows / "IRON_PULSE_BLACKOUT.exe"
    exe.write_bytes(b"MZ" + b"FAKE_TEST_ONLY" * 800_000)
    (windows / "IRON_PULSE_BLACKOUT.pck").write_bytes(b"GDPC" + b"TEST" * 1000)
    contents = {}
    for relative in vault.SITE_CORE:
        if relative == "assets/build-proof.json":
            continue
        candidate = site / relative
        contents[relative] = {
            "size": candidate.stat().st_size,
            "sha256": vault.digest(candidate)
        }
    (site / "assets" / "build-proof.json").write_text(json.dumps({
        "schema": "IRON_PULSE_WORLD_SOURCE_BOUND_V13",
        "source_sha": sha,
        "status": "SOFTWARE_PREVIEW",
        "production_approved": False,
        "hardware_tested": False,
        "runtime_verified_against_export": True,
        "browser_capture_unchanged_sha256": vault.digest(
            site / "assets/gameplay-proof.png"),
        "files": contents,
    }), encoding="utf-8")
    (proof / "SOURCE_SHA.txt").write_text(sha + "\n", encoding="utf-8")
    (proof / "RELEASE_HOLD.txt").write_text("PRODUCTION HOLD\n", encoding="utf-8")
    (proof / "V12_SOURCE_REVIEW.json").write_text(
        json.dumps({"production_ready": False}), encoding="utf-8")
    build_core = (
        [web / n for n in ("index.html", "index.js", "index.wasm", "index.pck")] +
        [windows / n for n in vault.WINDOWS_FILES]
    )
    world_core = (
        [site / "play" / n for n in ("index.html", "index.js", "index.wasm", "index.pck")] +
        [site / n for n in ("index.html", "styles.css", "app.js",
                             "assets/gameplay-proof.png", "assets/build-proof.json")]
    )
    for label, selected in (("SHA256SUMS.txt", build_core),
                            ("WORLD_SHA256SUMS.txt", world_core)):
        (proof / label).write_text(
            "".join(f"{vault.digest(path)}  {path.relative_to(base).as_posix()}\n"
                    for path in selected),
            encoding="utf-8"
        )
    return site, web, windows, proof


class G5ReleaseVaultTests(unittest.TestCase):
    SHA_A = "a" * 40
    SHA_B = "b" * 40

    def setUp(self) -> None:
        self.temp = tempfile.TemporaryDirectory(prefix="iron-pulse-g5-test-")
        self.root = Path(self.temp.name)
        self.source = fixture(self.root, self.SHA_A)

    def tearDown(self) -> None:
        self.temp.cleanup()

    def _build(self, sha: str, source=None, tag="") -> tuple[Path, dict]:
        paths = source if source is not None else self.source
        destination = self.root / f"release-{sha[:8]}{tag}.zip"
        receipt = self.root / f"receipt-{sha[:8]}{tag}.json"
        data = vault.package(*paths, sha, destination, receipt)
        self.assertEqual(data["source_sha"], sha)
        self.assertEqual(data["package_sha256"], vault.digest(destination))
        self.assertTrue(data["release_hold"])
        self.assertFalse(data["production_approved"])
        self.assertTrue(receipt.is_file())
        return destination, data

    def test_01_deterministic_exact_source_build(self) -> None:
        zip1, data1 = self._build(self.SHA_A)
        zip2, data2 = self._build(self.SHA_A, tag="-copy")
        self.assertEqual(data1["package_sha256"], data2["package_sha256"])
        self.assertEqual(zip1.read_bytes(), zip2.read_bytes(),
                         "ZIP is reproducible and independent of local file mtimes")
        record = vault.verify_archive(zip1, expected_sha=self.SHA_A,
                                      expected_bundle_sha256=data1["package_sha256"])
        self.assertTrue(record["verified"])
        self.assertFalse(record["production_approved"])
        self.assertGreater(record["file_count"], 15)
        with self.assertRaises(vault.VaultError):
            vault.verify_archive(zip1, expected_sha=self.SHA_B)
        with self.assertRaises(vault.VaultError):
            vault.verify_archive(zip1, expected_bundle_sha256="0" * 64)

    def test_02_safe_stage_cas_switch_and_verified_rollback(self) -> None:
        zip_a, receipt_a = self._build(self.SHA_A)
        source_b = fixture(self.root, self.SHA_B)
        zip_b, receipt_b = self._build(self.SHA_B, source=source_b)
        root = self.root / "vault"
        a = vault.stage(zip_a, root, self.SHA_A, receipt_a["package_sha256"])
        b = vault.stage(zip_b, root, self.SHA_B, receipt_b["package_sha256"])
        self.assertEqual(a["status"], "staged-not-deployed")
        self.assertEqual(b["status"], "staged-not-deployed")
        self.assertEqual(vault.stage(zip_a, root, self.SHA_A,
                                     receipt_a["package_sha256"])["status"], "already-staged")
        self.assertIsNone(vault.status(root)["current"])
        with self.assertRaises(vault.VaultError):
            vault.rollback(root, "none")
        with self.assertRaises(vault.VaultError):
            vault.activate(root, self.SHA_B, self.SHA_A)
        first = vault.activate(root, self.SHA_A, "none")
        self.assertEqual(first["generation"], 1)
        self.assertFalse(first["deployment_performed"])
        with self.assertRaises(vault.VaultError):
            vault.activate(root, self.SHA_B, "none")
        second = vault.activate(root, self.SHA_B, self.SHA_A)
        self.assertEqual(second["current"], self.SHA_B)
        self.assertEqual(second["previous"], self.SHA_A)
        self.assertEqual(second["generation"], 2)
        rolled = vault.rollback(root, self.SHA_B)
        self.assertEqual(rolled["current"], self.SHA_A)
        self.assertEqual(rolled["previous"], self.SHA_B)
        self.assertEqual(rolled["generation"], 3)
        self.assertFalse(rolled["deployment_performed"])
        self.assertEqual(vault.status(root)["current_verified"]["sha"], self.SHA_A)
        # The verification gate must fail CLOSED when staged data changes.
        target = root / "releases" / self.SHA_A / "site" / "app.js"
        target.write_bytes(target.read_bytes() + b"tamper")
        with self.assertRaises(vault.VaultError):
            vault.status(root)
        with self.assertRaises(vault.VaultError):
            vault.activate(root, self.SHA_B, self.SHA_A)

    def test_03_reject_corrupted_and_ambiguous_archives(self) -> None:
        zip_a, receipt = self._build(self.SHA_A)
        altered = self.root / "altered.zip"
        data = bytearray(zip_a.read_bytes())
        data[50] ^= 1
        altered.write_bytes(data)
        with self.assertRaises((vault.VaultError, zipfile.BadZipFile, OSError)):
            vault.verify_archive(altered, expected_bundle_sha256=receipt["package_sha256"])
        for name, payload in (
            ("../escape.txt", b"outside"),
            ("site/APP.js", b"case_alias"),
            ("site/malware.js", b"unapproved"),
        ):
            modified = self.root / ("injected-" + name.replace("/", "_").replace(".", "_") + ".zip")
            shutil.copyfile(zip_a, modified)
            with zipfile.ZipFile(modified, "a") as archive:
                archive.writestr(name, payload)
            with self.assertRaises(vault.VaultError):
                vault.verify_archive(modified)
        link = self.root / "symlink.zip"
        shutil.copyfile(zip_a, link)
        info = zipfile.ZipInfo("site/extra-link")
        info.create_system = 3
        info.external_attr = ((stat.S_IFLNK | 0o777) << 16)
        with zipfile.ZipFile(link, "a") as archive:
            archive.writestr(info, "../target")
        with self.assertRaises(vault.VaultError):
            vault.verify_archive(link)
        duplicate = self.root / "duplicate.zip"
        shutil.copyfile(zip_a, duplicate)
        with warnings.catch_warnings():
            warnings.simplefilter("ignore", UserWarning)
            with zipfile.ZipFile(duplicate, "a") as archive:
                archive.writestr("site/app.js", "repeated")
        with self.assertRaises(vault.VaultError):
            vault.verify_archive(duplicate)

    def test_04_mixed_build_and_untrusted_stage_rejected(self) -> None:
        site, web, win, proof = self.source
        exe = win / "IRON_PULSE_BLACKOUT.exe"
        exe.write_bytes(exe.read_bytes() + b"wrong-version")
        with self.assertRaises(vault.VaultError):
            self._build(self.SHA_A)
        # A clean source cannot be staged without its external hash.
        valid = fixture(self.root, self.SHA_B)
        zip_b, receipt = self._build(self.SHA_B, source=valid)
        with self.assertRaises(vault.VaultError):
            vault.stage(zip_b, self.root / "vault", self.SHA_B, "0" * 64)
        with self.assertRaises(vault.VaultError):
            vault.stage(zip_b, self.root / "vault", self.SHA_A, receipt["package_sha256"])
        self.assertFalse((self.root / "vault" / "releases" / self.SHA_B).exists())

    def test_05_manifest_has_no_fake_signing_or_device_approval(self) -> None:
        archive, receipt = self._build(self.SHA_A)
        with zipfile.ZipFile(archive) as z:
            manifest = json.loads(z.read(vault.MANIFEST_NAME))
        self.assertEqual(manifest["status"], "TECHNICAL_PREVIEW_RELEASE_HOLD")
        self.assertFalse(manifest["cryptographically_signed"])
        self.assertFalse(manifest["physical_devices_certified"])
        self.assertFalse(manifest["production_approved"])
        self.assertNotIn("user_email", json.dumps(manifest))
        self.assertTrue(receipt["release_hold"])


if __name__ == "__main__":
    unittest.main(verbosity=2)
