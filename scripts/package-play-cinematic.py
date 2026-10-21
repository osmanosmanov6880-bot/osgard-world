#!/usr/bin/env python3
"""Package PLAY, or explicitly the reviewed global frontend, without game directories."""
from __future__ import annotations

import argparse
import importlib.util
import io
import json
import os
from pathlib import Path
import stat
import subprocess
import sys
import tarfile
import tempfile


INSTALLER_PATH = Path(__file__).with_name("install-play-cinematic.py")
SPEC = importlib.util.spec_from_file_location("osgard_play_installer", INSTALLER_PATH)
if SPEC is None or SPEC.loader is None:
    raise RuntimeError("Keep install-play-cinematic.py beside this packaging script")
POLICY = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(POLICY)
# Exact original bytes in commit 825f28a66877fb07cd9da07fda9c7d3cbc6b87db.
# This guard must not be refreshed merely to bypass a newer production game.
GAME_FIX_PREVIOUS = {"games/vector-zero/index.html": "a5709529b057ba827a10fcf2e92ae4e25fedbf9b9afc1740922ad1a7fcf31704"}


def safe_source_file(dist: Path, relative: str, global_frontend: bool = False) -> bytes:
    POLICY.require_allowed(relative, global_frontend)
    current = dist
    for part in POLICY.relative_parts(relative):
        current = current / part
        info = current.lstat()
        if stat.S_ISLNK(info.st_mode):
            raise POLICY.ReleaseError("Build output contains a symlink: " + relative)
        if current != dist / relative and not stat.S_ISDIR(info.st_mode):
            raise POLICY.ReleaseError("Build output parent is not a directory: " + relative)
    info = current.stat()
    if not stat.S_ISREG(info.st_mode) or not 0 < info.st_size <= POLICY.MAX_FILE_BYTES:
        raise POLICY.ReleaseError("Build output is not a bounded regular file: " + relative)
    data = current.read_bytes()
    after = current.stat()
    if (info.st_size, info.st_mtime_ns, info.st_ino) != (after.st_size, after.st_mtime_ns, after.st_ino):
        raise POLICY.ReleaseError("Build output changed while packaging: " + relative)
    return data


def collect_payload(dist: Path, global_frontend: bool = False) -> dict[str, bytes]:
    if not dist.is_dir() or dist.is_symlink():
        raise POLICY.ReleaseError("--dist must be a real build directory")
    html_paths = POLICY.GLOBAL_HTML_PATHS if global_frontend else POLICY.HTML_PATHS
    paths = set(html_paths | POLICY.GAME_FIX_PATHS | POLICY.FIXED_ASSET_PATHS)
    if global_frontend:
        paths.update(POLICY.INTRO_ASSET_PATHS)
    for directory, suffixes in ((dist / "assets", {".js", ".css"}), (dist / "brand/play", {".webp"})):
        if not directory.is_dir() or directory.is_symlink():
            raise POLICY.ReleaseError("Missing or unsafe build directory: " + str(directory))
        for path in directory.rglob("*"):
            if path.is_symlink():
                raise POLICY.ReleaseError("Build resource is a symlink: " + str(path.relative_to(dist)))
            if path.is_file() and path.suffix in suffixes:
                relative = path.relative_to(dist).as_posix()
                POLICY.require_allowed(relative, global_frontend)
                paths.add(relative)
    worlds = dist / "play/world"
    if not worlds.is_dir() or worlds.is_symlink():
        raise POLICY.ReleaseError("Build has no safe play/world directory")
    for world in worlds.iterdir():
        if world.is_symlink():
            raise POLICY.ReleaseError("World directory is a symlink: " + world.name)
        if world.is_dir():
            relative = (world / "index.html").relative_to(dist).as_posix()
            POLICY.require_allowed(relative, global_frontend)
            paths.add(relative)
    if len(paths) > POLICY.MAX_FILES:
        raise POLICY.ReleaseError("Too many release files")
    payload = {path: safe_source_file(dist, path, global_frontend) for path in sorted(paths, key=lambda value: (value.endswith(".html"), value))}
    if sum(map(len, payload.values())) > POLICY.MAX_TOTAL_BYTES:
        raise POLICY.ReleaseError("Release exceeds the total size limit")
    return payload


def verify_generated_shell_registry(repo: Path) -> None:
    """Evaluate the actual route declarations, without running build output writes.

    The build script and catalog are trusted checkout code, like npm run build.
    The installer independently keeps a fixed list and never trusts a list from
    a server, archive or directory glob to enlarge the release scope.
    """
    script = r"""
import { readFileSync } from 'node:fs';
import vm from 'node:vm';
import { build } from 'esbuild';
const source = readFileSync('scripts/build-brand-routes.mjs', 'utf8');
const starts = [...source.matchAll(/\bconst routes\s*=\s*\[/g)];
const ends = [...source.matchAll(/\bconst esc\s*=/g)];
if (starts.length !== 1 || ends.length !== 1 || starts[0].index >= ends[0].index) {
  throw new Error('Route builder changed structure; review the fixed frontend registry before packaging');
}
const bundle = await build({ entryPoints: ['src/redesignCatalog.ts'], bundle: true, write: false, format: 'esm', platform: 'node' });
const { playGames } = await import('data:text/javascript;base64,' + Buffer.from(bundle.outputFiles[0].text).toString('base64'));
const declaration = source.slice(starts[0].index, ends[0].index);
const paths = vm.runInNewContext(declaration + '\n; routes.map(route => route[0] + "/index.html")', { playGames }, { timeout: 1000 });
process.stdout.write(JSON.stringify(['index.html', ...paths].sort()));
"""
    try:
        result = subprocess.run(["node", "--input-type=module", "--eval", script], cwd=repo,
                                check=True, text=True, capture_output=True, timeout=30)
        paths = json.loads(result.stdout)
    except (OSError, subprocess.CalledProcessError, subprocess.TimeoutExpired, ValueError) as error:
        raise POLICY.ReleaseError("Cannot verify generated React shells; install build dependencies and review scripts/build-brand-routes.mjs") from error
    if not isinstance(paths, list) or any(not isinstance(path, str) for path in paths) or len(set(paths)) != len(paths):
        raise POLICY.ReleaseError("The route builder did not return a unique shell registry")
    actual = set(paths)
    if actual != POLICY.GLOBAL_HTML_PATHS:
        added = sorted(actual - POLICY.GLOBAL_HTML_PATHS)
        removed = sorted(POLICY.GLOBAL_HTML_PATHS - actual)
        raise POLICY.ReleaseError("Generated React shell registry changed; review the fixed installer allowlist. Added: " + repr(added) + "; removed: " + repr(removed))


def source_identity(repo: Path, allow_dirty: bool) -> dict:
    try:
        sha = subprocess.run(["git", "rev-parse", "HEAD"], cwd=repo, check=True, text=True, capture_output=True).stdout.strip()
        status = subprocess.run(["git", "status", "--porcelain", "--untracked-files=normal"], cwd=repo, check=True, text=True, capture_output=True).stdout
    except (OSError, subprocess.CalledProcessError) as error:
        raise POLICY.ReleaseError("Cannot determine source commit from this checkout") from error
    if not POLICY.SOURCE_RE.fullmatch(sha):
        raise POLICY.ReleaseError("Invalid Git source commit")
    dirty = bool(status.strip())
    if dirty and not allow_dirty:
        raise POLICY.ReleaseError("Working tree has uncommitted changes. Commit before the release build, or use --allow-dirty for an explicitly marked review package.")
    return {"git_commit": sha, "working_tree_dirty": dirty}


def write_package(output: Path, manifest: dict, payload: dict[str, bytes], global_frontend: bool = False) -> None:
    output = output.absolute()
    if ".." in output.parts:
        raise POLICY.ReleaseError("Output path must not contain '..'")
    current = output.parent
    while current != current.parent:
        if current.is_symlink():
            raise POLICY.ReleaseError("Output parent has a symlink ancestor")
        current = current.parent
    if output.exists() or output.is_symlink():
        raise POLICY.ReleaseError("Output already exists; choose a new archive filename")
    if not output.parent.is_dir() or output.parent.is_symlink():
        raise POLICY.ReleaseError("Output parent must be an existing real directory")
    fd, temporary = tempfile.mkstemp(prefix=".osgard-play-package-", suffix=".tmp", dir=output.parent)
    os.close(fd)
    try:
        with tarfile.open(temporary, "w:gz", format=tarfile.USTAR_FORMAT) as archive:
            values = [("manifest.json", POLICY.json_bytes(manifest))]
            values += [("payload/" + path, data) for path, data in payload.items()]
            for name, data in values:
                member = tarfile.TarInfo(name)
                member.size = len(data)
                member.mode = 0o644
                member.mtime = 0
                member.uid = member.gid = 0
                archive.addfile(member, io.BytesIO(data))
        # Verify the serialized archive before its final name is made visible.
        if os.name == "posix":
            verified, copied, _ = POLICY.read_archive(Path(temporary), global_frontend)
            if verified != manifest or copied != payload:
                raise POLICY.ReleaseError("Package verification mismatch")
        with open(temporary, "rb") as stream:
            os.fsync(stream.fileno())
        os.replace(temporary, output)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--dist", type=Path, default=Path(__file__).resolve().parents[1] / "dist")
    parser.add_argument("--output", type=Path, required=True, help="New archive path outside dist; never overwrite an existing package")
    parser.add_argument("--allow-dirty", action="store_true", help="Mark an uncommitted local-review package honestly in its manifest")
    parser.add_argument("--global-frontend", action="store_true", help="Explicitly include root and all 82 generated React shells plus six fixed intro images")
    args = parser.parse_args(argv)
    try:
        repo = Path(__file__).resolve().parents[1]
        dist = args.dist.absolute()
        if ".." in dist.parts:
            raise POLICY.ReleaseError("--dist must not contain '..'")
        # Reject ancestor symlinks as well as symlink files inside the build.
        current = dist
        while current != current.parent:
            if current.is_symlink():
                raise POLICY.ReleaseError("Build directory has a symlink ancestor")
            current = current.parent
        output = args.output.absolute()
        if output == dist or dist in output.parents:
            raise POLICY.ReleaseError("Write the package outside dist")
        source = source_identity(repo, args.allow_dirty)
        if args.global_frontend:
            verify_generated_shell_registry(repo)
        payload = collect_payload(dist, args.global_frontend)
        manifest = {"kind": POLICY.GLOBAL_KIND if args.global_frontend else POLICY.KIND,
                    "schema_version": POLICY.SCHEMA, "created_at": POLICY.utc_now(),
                    "source": source, "path_allowlist": POLICY.GLOBAL_PATH_POLICY if args.global_frontend else POLICY.PATH_POLICY,
                    "expected_previous": GAME_FIX_PREVIOUS,
                    "files": [{"path": path, "size": len(data), "sha256": POLICY.digest(data)} for path, data in payload.items()]}
        POLICY.validate_manifest(manifest, args.global_frontend)
        write_package(output, manifest, payload, args.global_frontend)
        print(json.dumps({"status": "PACKAGED", "archive": str(output), "archive_sha256": POLICY.digest(output.read_bytes()),
                          "files": len(payload), "payload_bytes": sum(map(len, payload.values())), "source": source,
                          "release_kind": manifest["kind"], "react_shells": len(POLICY.GLOBAL_HTML_PATHS) if args.global_frontend else "PLAY routes and aliases plus Time",
                          "excluded": ["standalone game directories except fixed VECTOR HTML; the Time React shell is included", "backend", "Nginx configuration", "secrets"] + ([] if args.global_frontend else ["root index.html", "non-PLAY React shells", "intro assets"])}, ensure_ascii=False, indent=2))
        return 0
    except (POLICY.ReleaseError, OSError, ValueError) as error:
        print(json.dumps({"status": "REJECTED", "error": str(error)}, ensure_ascii=False), file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
