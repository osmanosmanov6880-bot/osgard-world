#!/usr/bin/env python3
"""R6 hero sports car: pinned upstream CC0 GLB, verified as a real asset.
Source https://github.com/JaronKBragg7337/spectral-gt-rs
Explicitly not Forza IP and not an uncredited proprietary vehicle model.
"""
import argparse, hashlib, json, struct, urllib.request
from pathlib import Path
URL="https://raw.githubusercontent.com/JaronKBragg7337/spectral-gt-rs/main/"
SOURCE_GIT_SHA="f5b814848453a6c75a48f5047fdadaa7bdc78969"
LICENSE_GIT_SHA="8f40c549094ff25ff1e2a8cdc597f29f78195b9a"
MAX_LENGTH=18*1024*1024

def checked_download(file,git_sha):
    if file not in ("spectral_gt_rs_game_ready.glb","LICENSE"):
        raise ValueError("Unexpected upstream file")
    req=urllib.request.Request(URL+file,headers={"User-Agent":"OSGARD-Horizon-CC0-ModelImporter/1.0"})
    with urllib.request.urlopen(req,timeout=80) as f:
        data=f.read(MAX_LENGTH+1)
    if len(data)>MAX_LENGTH:
        raise ValueError("Model too large")
    actual=hashlib.sha1(b"blob "+str(len(data)).encode()+b"\0"+data).hexdigest()
    if actual!=git_sha:
        raise ValueError("Upstream pinned Git SHA mismatch "+actual)
    return data

def glb_details(data):
    if len(data)<24 or data[:4]!=b"glTF":
        raise ValueError("Not GLB")
    version,length=struct.unpack_from("<II",data,4)
    if version!=2 or length!=len(data):
        raise ValueError("Invalid glTF 2.0 file length/version")
    length,chunk=struct.unpack_from("<I4s",data,12)
    if chunk!=b"JSON":
        raise ValueError("First chunk is not JSON")
    parsed=json.loads(data[20:20+length])
    summary={kind:len(parsed.get(kind,[])) for kind in ("nodes","meshes","materials","animations","accessors","scenes")}
    if summary["meshes"]<30 or summary["materials"]<12 or summary["nodes"]<60 or summary["animations"]<2:
        raise ValueError("Not the detailed animated sports car: "+str(summary))
    if any(img.get("uri") for img in parsed.get("images",[])):
        raise ValueError("GLB must not depend on external image paths")
    return summary

def main():
    parser=argparse.ArgumentParser()
    parser.add_argument("--output",type=Path,default=Path("godot/empire-omega/assets/r6/vehicles"))
    args=parser.parse_args()
    args.output.mkdir(parents=True,exist_ok=True)
    model=checked_download("spectral_gt_rs_game_ready.glb",SOURCE_GIT_SHA)
    license_text=checked_download("LICENSE",LICENSE_GIT_SHA).decode()
    if "CC0 1.0 Universal" not in license_text or "SPDX-License-Identifier: CC0-1.0" not in license_text:
        raise ValueError("CC0 license proof missing")
    details=glb_details(model)
    path=args.output/"spectral_gt_rs_game_ready.glb"
    path.write_bytes(model)
    (args.output/"LICENSE_CC0.txt").write_text(license_text)
    meta={"source":"https://github.com/JaronKBragg7337/spectral-gt-rs","license":"CC0-1.0",
          "upstream_git_blob_sha":SOURCE_GIT_SHA,"sha256":hashlib.sha256(model).hexdigest(),
          "bytes":len(model),"geometry_summary":details,
          "front_axis":"+X","conversion":"Godot vehicle facing -Z rotates imported root 90 degrees Y"}
    (args.output/"SOURCE_PROVENANCE.json").write_text(json.dumps(meta,indent=2))
    print("R6 HERO CC0 GLB VERIFIED",json.dumps(meta),flush=True)
if __name__=="__main__":main()
