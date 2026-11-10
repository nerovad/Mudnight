#!/usr/bin/env bash
# Tower test — prove the risky half of Phase 1 WITHOUT ffplayout.
#
# The one question Phase 1 exists to answer: does a CONTINUOUS push segment
# cleanly into nginx-rtmp -> HLS, with clean clip boundaries? ffplayout's push
# is, at the transport level, exactly this: a single continuous encoder whose
# content changes from one clip to the next. So a looped ffmpeg concat push is a
# faithful stand-in — and it needs no ffplayout install and no network.
#
# It generates 4 short labelled clips locally (lavfi), conforms them to one
# house format, then pushes them on an infinite loop into the edge. Clean HLS
# with NO discontinuity tags at clip boundaries = pass.
#
# Usage:  ./tower-test.sh [stream_key] [seconds]
#   stream_key defaults to phase1-demo-key (matches watch.html)
#   seconds    defaults to run until Ctrl-C
set -euo pipefail
cd "$(dirname "$0")"

KEY="${1:-phase1-demo-key}"
RUN_SECS="${2:-0}"                       # 0 = run forever
EDGE="${EDGE:-rtmp://localhost:1935/live}"
MEDIA=media
mkdir -p "$MEDIA"

# --- 1. generate house-format clips (once) --------------------------------
# One encoder profile for all of them: 720p30, H.264, GOP 60, faststart, AAC.
# This is the "conform on ingest" idea in miniature — identical params are what
# make the concat boundaries seamless.
gen() { # name  tint
  local f="$MEDIA/$1.mp4"
  [[ -f "$f" ]] && return 0
  local base="testsrc=size=1280x720:rate=30:duration=5"
  local label="drawtext=text='$1':fontcolor=white:fontsize=72:box=1:boxcolor=$2@0.6:boxborderw=20:x=(w-tw)/2:y=(h-th)/2"
  # Try with a burned-in label; fall back to bare testsrc if drawtext/fontconfig
  # isn't available on this box.
  if ! ffmpeg -y -f lavfi -i "$base" -f lavfi -i "sine=frequency=300:duration=5" \
        -vf "$label" -c:v libx264 -preset veryfast -g 60 -keyint_min 60 \
        -pix_fmt yuv420p -c:a aac -ar 44100 -movflags +faststart "$f" \
        >/dev/null 2>&1; then
    ffmpeg -y -f lavfi -i "$base" -f lavfi -i "sine=frequency=300:duration=5" \
        -c:v libx264 -preset veryfast -g 60 -keyint_min 60 \
        -pix_fmt yuv420p -c:a aac -ar 44100 -movflags +faststart "$f" \
        >/dev/null 2>&1
  fi
}
echo "generating local house-format clips..."
gen SEGMENT-1 red
gen SEGMENT-2 green
gen SEGMENT-3 blue
gen SEGMENT-4 purple

# --- 2. concat list -------------------------------------------------------
: > "$MEDIA/concat.txt"
for f in SEGMENT-1 SEGMENT-2 SEGMENT-3 SEGMENT-4; do
  printf "file '%s'\n" "$PWD/$MEDIA/$f.mp4" >> "$MEDIA/concat.txt"
done

# --- 3. continuous push into the edge -------------------------------------
echo "pushing continuous loop -> $EDGE/$KEY"
echo "HLS will appear at http://localhost:8088/hls/$KEY/index.m3u8"
[[ "$RUN_SECS" != "0" ]] && echo "(running ${RUN_SECS}s)" || echo "(Ctrl-C to stop)"

# -re paces at realtime; -stream_loop -1 loops the concat forever; re-encoding
# on push gives one continuous PTS timeline across all clips (the whole point).
CMD=(ffmpeg -hide_banner -loglevel warning -re -stream_loop -1
     -f concat -safe 0 -i "$MEDIA/concat.txt"
     -c:v libx264 -preset veryfast -g 60 -keyint_min 60 -pix_fmt yuv420p
     -c:a aac -ar 44100 -f flv "$EDGE/$KEY")

if [[ "$RUN_SECS" != "0" ]]; then
  timeout "$RUN_SECS" "${CMD[@]}" || true
else
  "${CMD[@]}"
fi
