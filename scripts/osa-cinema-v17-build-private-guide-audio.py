#!/usr/bin/env python3
"""Create *private*, three-act synchronized voice guide tracks from fingerprinted sources.

Does not overwrite original film soundtracks, assert rights or certify narration
language. Review the audio visually and by listening before any real final mix.
"""
import argparse
import hashlib
import json
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
NARRATION = ROOT / "docs/OSA_CINEMA_V16_NARRATION_MANIFEST.json"
STARTS = (5.0, 79.0, 157.0)
FILM_SECONDS = 239.0
PRIVATE_STATUS = "PRIVATE_EDITORIAL_VOICE_GUIDE_NOT_RELEASED"


def hash_path(path):
    sha = hashlib.sha256()
    with path.open("rb") as handle:
        for data in iter(lambda: handle.read(1024 * 1024), b""):
            sha.update(data)
    return sha.hexdigest()


def script_duration(f):
    data = json.loads(subprocess.check_output([
        "ffprobe", "-v", "error", "-show_entries",
        "format=duration:stream=codec_name,codec_type,channels,sample_rate",
        "-of", "json", str(f)
    ], timeout=30, text=True))
    return data, float(data["format"]["duration"])


def source_sets(manifest):
    source = manifest.get("assets", [])
    if len(source) != 6:
        raise ValueError("Missing full six-source act narration manifest")
    selections = {}
    for locale in ("ru", "en"):
        tracks = sorted([x for x in source if x.get("locale") == locale], key=lambda x:x["act"])
        if [x["act"] for x in tracks] != [1, 2, 3]:
            raise ValueError("An actual narration source is missing for " + locale)
        if any(x.get("publicationStatus") != "blocked" or not x.get("sha256") for x in tracks):
            raise ValueError("Unexpected source release status")
        for index, item in enumerate(tracks):
            if STARTS[index] + item["durationSeconds"] > FILM_SECONDS:
                raise ValueError("Narration overflows source film")
            if index < 2 and STARTS[index] + item["durationSeconds"] >= STARTS[index+1]:
                raise ValueError("Proposed act narrations overlap")
        selections[locale] = tracks
    return selections


def render_private_guide(locale, tracks, audio_root, out_root):
    paths=[]
    for item in tracks:
        path=audio_root/item["file"]
        if path.is_symlink() or not path.is_file():
            raise ValueError("Source missing or not a safe regular file: "+item["file"])
        if path.stat().st_size != item["sizeBytes"] or hash_path(path) != item["sha256"]:
            raise ValueError("Source fingerprint differs: "+item["file"])
        info, seconds = script_duration(path)
        stream = next((s for s in info.get("streams", []) if s.get("codec_type")=="audio"), None)
        if not stream or stream.get("codec_name")!="mp3" or abs(seconds-item["durationSeconds"])>.12:
            raise ValueError("Codec or runtime mismatch: "+item["file"])
        paths.append(path)

    out_root.mkdir(parents=True,exist_ok=True)
    output=out_root/("OSA_CINEMA_V17_"+locale.upper()+"_ACT_GUIDE_PRIVATE_239S.m4a")
    filters="anullsrc=r=48000:cl=stereo:d=239[bg];"
    for index, start in enumerate(STARTS):
        milli=round(start*1000)
        filters+=f"[{index}:a]aresample=48000,pan=stereo|c0=c0|c1=c0,volume=-2dB,adelay={milli}|{milli}[a{index}];"
    filters+="[bg][a0][a1][a2]amix=inputs=4:normalize=0:duration=first:dropout_transition=0,atrim=duration=239[out]"
    command=["ffmpeg","-y","-nostdin","-hide_banner","-loglevel","error"]
    for path in paths:
        command+=["-i",str(path)]
    command+=["-filter_complex",filters,"-map","[out]","-t","239",
        "-c:a","aac","-b:a","160k",
        "-metadata","title=OSA CINEMA PRIVATE EDITORIAL AUDIO GUIDE "+locale.upper(),
        "-metadata","comment=PRIVATE REVIEW ONLY - LANGUAGE AND RIGHTS UNVERIFIED",
        str(output)]
    subprocess.run(command,check=True,timeout=180)
    info,seconds=script_duration(output)
    stream=next((s for s in info.get("streams", []) if s.get("codec_type")=="audio"),None)
    if not stream or stream["codec_name"]!="aac" or abs(seconds-FILM_SECONDS)>.12:
        raise ValueError("Private guide has wrong runtime or codec")
    return {
        "locale":locale,"file":output.name,"durationSeconds":round(seconds,3),
        "bytes":output.stat().st_size,"sha256":hash_path(output),
        "status":PRIVATE_STATUS,"releaseAuthorized":False,
        "sourceTracks":[{
            "file":track["file"],"startSeconds":STARTS[i],
            "sourceDurationSeconds":track["durationSeconds"],
            "endsAtSeconds":round(STARTS[i]+track["durationSeconds"],3)
        } for i,track in enumerate(tracks)],
    }


def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument("--audio-root",type=Path)
    p.add_argument("--out-root",type=Path)
    p.add_argument("--check-plan",action="store_true",help="Check timing only; does not need local MP3 originals")
    opts=p.parse_args()
    registry=json.loads(NARRATION.read_text("utf8"))
    sources=source_sets(registry)
    if opts.check_plan:
        print("OSA_CINEMA_V17_GUIDE_PLAN_PASS "+json.dumps({
            "actStarts":STARTS,"filmSeconds":FILM_SECONDS,
            "ruEnding":round(STARTS[-1]+sources["ru"][-1]["durationSeconds"],3),
            "enEnding":round(STARTS[-1]+sources["en"][-1]["durationSeconds"],3),
            "releaseAuthorized":False
        }))
        return
    if not opts.audio_root or not opts.out_root:
        p.error("--audio-root and --out-root are required to produce private guide audio")
    guides=[render_private_guide(locale,tracks,opts.audio_root,opts.out_root) for locale,tracks in sources.items()]
    result={"schemaVersion":1,"project":"OSA CINEMA V17",
        "masterPictureDurationSeconds":FILM_SECONDS,
        "timingBasis":"EDITORIAL PROPOSAL: static picture holds near 00:05, 01:19 and 02:37",
        "guideOriginalPictureSoundModified":False,
        "languageOrRightsApproved":False,"publicationAuthorized":False,"guides":guides}
    target=opts.out_root/"OSA_CINEMA_V17_PRIVATE_ACT_GUIDES.json"
    target.write_text(json.dumps(result,ensure_ascii=False,indent=2)+"\n",encoding="utf8")
    print("OSA_CINEMA_V17_GUIDES_PRIVATE_PASS "+json.dumps([{"locale":g["locale"],"bytes":g["bytes"],"sha256":g["sha256"]} for g in guides]))


if __name__=="__main__":
    main()
