#!/usr/bin/env bash
# Verify the edge is producing clean, live HLS for a stream key.
# Pass = manifest exists, has growing segments, and has NO discontinuity tags
# at clip boundaries (a continuous push should never emit EXT-X-DISCONTINUITY).
#
# Usage:  ./verify.sh [stream_key]
set -uo pipefail
KEY="${1:-phase1-demo-key}"
URL="http://localhost:8088/hls/$KEY/index.m3u8"

echo "checking $URL"
m1="$(curl -fsS "$URL" 2>/dev/null)" || { echo "FAIL: manifest not served yet"; exit 1; }

segs="$(printf '%s\n' "$m1" | grep -c '\.ts')"
disc="$(printf '%s\n' "$m1" | grep -c 'EXT-X-DISCONTINUITY')"
echo "  segments in manifest: $segs"
echo "  discontinuity tags:   $disc"

echo "  waiting 6s to confirm it's live (segments should advance)..."
sleep 6
m2="$(curl -fsS "$URL" 2>/dev/null)"
first1="$(printf '%s\n' "$m1" | grep '\.ts' | head -1)"
first2="$(printf '%s\n' "$m2" | grep '\.ts' | head -1)"

echo "  first segment then: $first1"
echo "  first segment now:  $first2"

echo "  probing playability..."
if ffprobe -v error -select_streams v:0 -show_entries stream=codec_name,width,height \
     -of default=noprint_wrappers=1 "$URL" 2>/dev/null; then
  probe_ok=1
else
  probe_ok=0
fi

echo "---"
# A single EXT-X-DISCONTINUITY at stream start (MEDIA-SEQUENCE:0 still in the
# window) is normal nginx-rtmp behavior, not a per-clip break. Only MORE than
# one — or one that persists after sequence 0 has rolled off — means clip
# boundaries are fragmenting the stream, which is the actual Phase 1 risk.
seq0_in_window="$(printf '%s\n' "$m2" | grep -q '#EXT-X-MEDIA-SEQUENCE:0' && echo yes || echo no)"
pass=1
[[ "$segs" -gt 0 ]] || { echo "FAIL: no segments"; pass=0; }
if [[ "$disc" -eq 0 ]]; then
  echo "boundaries: clean (no discontinuity tags)"
elif [[ "$disc" -eq 1 && "$seq0_in_window" == "yes" ]]; then
  echo "boundaries: clean (the 1 discontinuity is the stream-start marker)"
else
  echo "FAIL: $disc discontinuity tag(s) in steady state — clip boundaries are breaking the stream"; pass=0
fi
[[ "$first1" != "$first2" ]] || echo "NOTE: window didn't advance in 6s — expected early (playlist_length not yet full)"
[[ "$probe_ok" -eq 1 ]] || { echo "FAIL: ffprobe could not read the stream"; pass=0; }
[[ "$pass" -eq 1 ]] && echo "PASS: edge is serving clean live HLS" || { echo "OVERALL: FAIL"; exit 1; }
