#!/usr/bin/env python3
"""Verified Poly Haven CC0 offline 1K PBR texture acquisition, zero game HTTP."""
import hashlib
import json
import os
import struct
import sys
import urllib.request
from urllib.parse import urlsplit
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ASSET = "aerial_asphalt_01"
URL = "https://dl.polyhaven.org/file/ph-assets/Textures/jpg/1k/" + ASSET
OUT = ROOT / "godot/empire-omega/assets/r90"
LOCK = OUT / "provenance.json"
MAPS = {"albedo": ASSET+"_diff_1k.jpg",
        "normal_gl": ASSET+"_nor_gl_1k.jpg",
        "roughness": ASSET+"_rough_1k.jpg"}
MAX_BYTES = 5 * 1024 * 1024


def dimensions_jpeg(data):
    if len(data) < 100 or data[:2] != b"\xff\xd8" or data[-2:] != b"\xff\xd9":
        raise ValueError("unsafe JPEG data")
    i = 2
    while i + 4 <= len(data):
        if data[i] != 255:
            i += 1
            continue
        while i < len(data) and data[i] == 255:
            i += 1
        if i >= len(data):
            break
        marker = data[i]
        i += 1
        if marker == 0xDA:
            break
        if marker in (0xD8,0xD9,0x01) or 0xD0 <= marker <= 0xD7:
            continue
        if i + 2 > len(data):
            break
        size = struct.unpack_from(">H",data,i)[0]
        if size < 2 or i + size > len(data):
            raise ValueError("damaged JPEG segment")
        if marker in (0xC0,0xC1,0xC2,0xC3,0xC5,0xC6,0xC7,0xC9,0xCA,0xCB,0xCD,0xCE,0xCF):
            height,width = struct.unpack_from(">HH",data,i+3)
            return width,height
        i += size
    raise ValueError("missing JPEG SOF")


def inspect(kind,blob):
    if not 2048 <= len(blob) <= MAX_BYTES:
        raise ValueError(kind + ": unbounded file")
    w,h = dimensions_jpeg(blob)
    if (w,h) != (1024,1024):
        raise ValueError(kind + ": unexpected resolution")
    return {"file":MAPS[kind],"sha256":hashlib.sha256(blob).hexdigest(),
            "bytes":len(blob),"width":w,"height":h}


def verify():
    data = json.loads(LOCK.read_text(encoding="utf-8"))
    if data.get("asset") != ASSET or data.get("license") != "CC0" or data.get("source") != "https://polyhaven.com/a/" + ASSET:
        raise ValueError("bad source/license provenance")
    for kind,name in MAPS.items():
        actual = inspect(kind,(OUT / name).read_bytes())
        if data["files"][kind] != actual:
            raise ValueError("PBR SHA256 mismatch: "+name)
        print("PASS R90 CC0",name,actual["sha256"],flush=True)


def fetch():
    OUT.mkdir(parents=True,exist_ok=True)
    # Refuse unreviewed sources: build-time fetch must be reproducible.
    # Every original asset byte is already approved by the committed lock.
    if not LOCK.is_file():
        raise ValueError("missing reviewed CC0 provenance lock; refusing unpinned remote bytes")
    prior = json.loads(LOCK.read_text(encoding="utf-8"))
    assets = {}
    results = {}
    for kind,name in MAPS.items():
        req = urllib.request.Request(URL+"/"+name,headers={"User-Agent":"OSGARD-Empire-R90-Offline-PBR/1.0","Accept":"image/jpeg"})
        with urllib.request.urlopen(req,timeout=45) as response:
            actual_url = urlsplit(response.geturl())
            if actual_url.scheme != "https" or actual_url.hostname != "dl.polyhaven.org":
                raise ValueError("untrusted upstream redirect: "+actual_url.hostname if actual_url.hostname else "untrusted URL")
            blob = response.read(MAX_BYTES+1)
        value = inspect(kind,blob)
        if prior["files"].get(kind) != value:
            raise ValueError("upstream changed; manual re-pin is required: "+name)
        assets[name]=blob
        results[kind]=value
    manifest={"asset":ASSET,"source":"https://polyhaven.com/a/"+ASSET,
              "license":"CC0","license_url":"https://polyhaven.com/license","files":results}
    if manifest != prior:
        raise ValueError("manifest changed without review")
    for name,blob in assets.items():
        tmp=OUT/(name+".pending")
        tmp.write_bytes(blob)
        os.replace(tmp,OUT/name)
    LOCK.write_text(json.dumps(manifest,ensure_ascii=False,sort_keys=True,indent=2)+"\n",encoding="utf-8")
    verify()


if __name__ == "__main__":
    if len(sys.argv)!=2 or sys.argv[1] not in ("fetch","verify"):
        raise SystemExit("usage: r90_cc0_texture_pack.py fetch|verify")
    fetch() if sys.argv[1]=="fetch" else verify()
