#!/usr/bin/env bash
# Private editorial utility. This file does NOT authorize film publication.
set -euo pipefail
if (( $# < 2 )); then
  echo 'Usage: bash osa-cinema-v18-private-four-track.sh --check-plan|--render PRIVATE_SOURCE_DIR [PRIVATE_OUTPUT_DIR]' >&2
  exit 2
fi
MODE=$1
ROOT=$2
OUT=$ROOT/private-dual-audio
if (( $# >= 3 )); then OUT=$3; fi
if [[ "$MODE" != "--check-plan" && "$MODE" != "--render" ]]; then exit 2; fi
[[ -d "$ROOT" ]] || { echo 'Missing private source directory' >&2; exit 2; }
for tool in ffmpeg ffprobe sha256sum awk; do command -v "$tool" >/dev/null || exit 2; done
for LANG in RU EN; do
  printf -v VIDEO '%s/OSA_CINEMA_V15_DIRECTORS_WORKPRINT_%s_1080P.mp4' "$ROOT" "$LANG"
  printf -v GUIDE '%s/OSA_CINEMA_V17_%s_ACT_GUIDE_PRIVATE_239S.m4a' "$ROOT" "$LANG"
  case "$LANG" in
    RU) VIDEO_SHA=74a040f9c67155eca946d6c6bed462e7edfb9c4f866605a0c2ecdd9568202b01
        GUIDE_SHA=2763cb455cb926fafd3eafa0d11c6882d157a16ca9c086f03a6cbc258b9b4f50 ;;
    EN) VIDEO_SHA=2936222a5be4b36ab3177f1577219831ab686e085be9b0744887bbcae05a7e36
        GUIDE_SHA=15f68c069476203c1208f7f69a0586b2e4b8443a1ec6750f266f6e1816c6df80 ;;
  esac
  [[ -f "$VIDEO" && ! -L "$VIDEO" && -f "$GUIDE" && ! -L "$GUIDE" ]] || { echo "$LANG source file missing" >&2; exit 3; }
  [[ "$(sha256sum "$VIDEO" | awk '{print $1}')" == "$VIDEO_SHA" ]] || { echo "$LANG video SHA mismatch" >&2; exit 4; }
  [[ "$(sha256sum "$GUIDE" | awk '{print $1}')" == "$GUIDE_SHA" ]] || { echo "$LANG guide SHA mismatch" >&2; exit 4; }
done
if [[ "$MODE" == "--check-plan" ]]; then echo 'PRIVATE_SOURCE_SHA_PASS_NO_PUBLIC_RIGHTS'; exit 0; fi
mkdir -p "$OUT"
DEST="$OUT/OSA_CINEMA_V18_PRIVATE_FOUR_TRACK_EDITORIAL_239S.mp4"
ffmpeg -y -nostdin -hide_banner -loglevel error \
  -i "$ROOT/OSA_CINEMA_V15_DIRECTORS_WORKPRINT_RU_1080P.mp4" \
  -i "$ROOT/OSA_CINEMA_V15_DIRECTORS_WORKPRINT_EN_1080P.mp4" \
  -i "$ROOT/OSA_CINEMA_V17_RU_ACT_GUIDE_PRIVATE_239S.m4a" \
  -i "$ROOT/OSA_CINEMA_V17_EN_ACT_GUIDE_PRIVATE_239S.m4a" \
  -filter_complex '[0:a:0]volume=-12dB,aresample=48000[br];[2:a:0]aresample=48000[gr];[br][gr]amix=inputs=2:duration=first:normalize=0:dropout_transition=0,alimiter=limit=0.8,volume=-3dB[mr];[1:a:0]volume=-12dB,aresample=48000[be];[3:a:0]aresample=48000[ge];[be][ge]amix=inputs=2:duration=first:normalize=0:dropout_transition=0,alimiter=limit=0.8,volume=-3dB[me]' \
  -map 0:v:0 -map 0:a:0 -map 1:a:0 -map '[mr]' -map '[me]' \
  -c:v copy -c:a:0 copy -c:a:1 copy -c:a:2 aac -c:a:3 aac \
  -b:a:2 192k -b:a:3 192k -ac:a:2 2 -ac:a:3 2 -ar:a:2 48000 -ar:a:3 48000 \
  -metadata title='OSA CINEMA PRIVATE 4-TRACK EDITORIAL - NOT RELEASED' \
  -metadata:s:a:0 title='Original RU candidate - unverified' \
  -metadata:s:a:1 title='Original EN candidate - unverified' \
  -metadata:s:a:2 title='Draft RU guide - not approved' \
  -metadata:s:a:3 title='Draft EN guide - not approved' \
  -disposition:a:0 default -disposition:a:1 0 -disposition:a:2 0 -disposition:a:3 0 \
  -movflags +faststart "$DEST"
[[ "$(ffprobe -v error -select_streams a -show_entries stream=index -of csv=p=0 "$DEST" | wc -l)" -eq 4 ]] || exit 5
# Verify the original picture and both original soundtrack packet streams are
# bit-for-bit unchanged, not merely declared as stream-copy in command flags.
hash_stream() {
  ffmpeg -nostdin -hide_banner -loglevel error -i "$1" -map "$2" -c copy -f hash -hash sha256 - | awk -F= '/^SHA256=/{print $2}'
}
RV=$(hash_stream "$ROOT/OSA_CINEMA_V15_DIRECTORS_WORKPRINT_RU_1080P.mp4" 0:v:0)
EV=$(hash_stream "$ROOT/OSA_CINEMA_V15_DIRECTORS_WORKPRINT_EN_1080P.mp4" 0:v:0)
OV=$(hash_stream "$DEST" 0:v:0)
RA=$(hash_stream "$ROOT/OSA_CINEMA_V15_DIRECTORS_WORKPRINT_RU_1080P.mp4" 0:a:0)
EA=$(hash_stream "$ROOT/OSA_CINEMA_V15_DIRECTORS_WORKPRINT_EN_1080P.mp4" 0:a:0)
ORA=$(hash_stream "$DEST" 0:a:0)
OEA=$(hash_stream "$DEST" 0:a:1)
[[ -n "$RV" && "$RV" == "$EV" && "$RV" == "$OV" ]] || { echo 'Picture streams are not identical' >&2; exit 7; }
[[ -n "$RA" && -n "$EA" && "$RA" == "$ORA" && "$EA" == "$OEA" ]] || { echo 'Original soundtrack packets changed' >&2; exit 8; }
echo 'SOURCE_PICTURE_AND_TWO_AUDIO_BITSTREAMS_PRESERVED'

for TRACK in 2 3; do
  PEAK=$(ffmpeg -nostdin -hide_banner -loglevel info -i "$DEST" -map "0:a:$TRACK" -af ebur128=peak=true -f null - 2>&1 | awk '/Summary:/{s=1} s && /Peak:/{v=$2} END{print v}')
  awk -v p="$PEAK" 'BEGIN{exit (p=="" || (p+0)>-1)?1:0}' || { echo "Draft true peak unsafe: $PEAK dBTP" >&2; exit 6; }
done
ffmpeg -nostdin -hide_banner -loglevel error -threads 2 -i "$DEST" \
  -map 0:v:0 -map 0:a:0 -map 0:a:1 -map 0:a:2 -map 0:a:3 -f null -
sha256sum "$DEST"
echo 'PRIVATE_MULTITRACK_QA_PASS: NO PUBLICATION RIGHTS GRANTED'
