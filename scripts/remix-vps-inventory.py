#!/usr/bin/env python3
"""Read only REMIX source/build metadata; never export source, env or data files."""
import hashlib
import json
import os
import subprocess
from pathlib import Path


def docker(*args):
    result = subprocess.run(["docker", *args], text=True, capture_output=True, timeout=20)
    return result.stdout.strip() if result.returncode == 0 else None


report = {"schemaVersion": 1, "sourceRoots": [], "containers": []}
roots = {Path("/opt/remix")}
for name in ("remix-api", "osgard-world"):
    working = docker("inspect", "--format", '{{index .Config.Labels "com.docker.compose.project.working_dir"}}', name)
    report["containers"].append({
        "name": name,
        "status": docker("inspect", "--format", "{{.State.Status}}", name),
        "workingDirectory": working,
        "imageWorkingDirectory": docker("inspect", "--format", "{{.Config.WorkingDir}}", name),
    })
    if working and working.startswith("/"):
        project = Path(working)
        roots.update({project / "remix", project.parent / "remix"})

allowed_suffixes = {".cs", ".go", ".py", ".ts", ".js", ".unity", ".csproj", ".sln"}
allowed_names = {"Dockerfile", "go.mod", "package.json", "ProjectVersion.txt", "README.md"}
excluded = {".git", "node_modules", "Library", "Temp", "Logs", "obj", "bin", "Build", "Builds", "UserSettings", "__pycache__"}
for root in sorted(roots):
    entry = {"root": str(root), "exists": root.is_dir(), "files": []}
    report["sourceRoots"].append(entry)
    if not root.is_dir() or root.is_symlink():
        continue
    for current, dirs, files in os.walk(root, followlinks=False):
        relative = Path(current).relative_to(root)
        dirs[:] = sorted(d for d in dirs if not d.startswith(".") and d not in excluded and not (Path(current) / d).is_symlink()) if len(relative.parts) < 9 else []
        for name in sorted(files):
            path = Path(current) / name
            if path.is_symlink() or name.startswith(".") or (path.suffix not in allowed_suffixes and name not in allowed_names):
                continue
            size = path.stat().st_size
            record = {"path": str(path.relative_to(root)), "bytes": size}
            # Only structural counts leave the VPS; no source text or values.
            if size <= 2_000_000:
                data = path.read_bytes()
                record["sha256"] = hashlib.sha256(data).hexdigest()
                record["lines"] = len(data.splitlines())
                if path.suffix == ".unity":
                    record["gameObjects"] = data.count(b"GameObject:")
                    record["cameras"] = data.count(b"Camera:")
                    record["monoBehaviours"] = data.count(b"MonoBehaviour:")
                elif path.suffix in {".go", ".py", ".js", ".ts", ".cs"}:
                    record["contractMarkers"] = [marker for marker in ("replayFrames", "remainingMs", "lastSequence", "RESULTS", "COUNTDOWN", "sqlite", "postgres", "Redis", "SceneManager", "RuntimeInitializeOnLoadMethod") if marker.encode() in data]
            entry["files"].append(record)
            if len(entry["files"]) >= 400:
                entry["truncated"] = True
                break
        if entry.get("truncated"):
            break

print(json.dumps(report, ensure_ascii=False, indent=2))
