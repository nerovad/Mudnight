#!/usr/bin/env bash
# Generate today's playlist for the harness, into the exact tree layout
# ffplayout pulls from:  <root>/YYYY/MM/YYYY-MM-DD.json
#
# This deliberately models Cinezoo's real responsibility in URL mode: because
# ffplayout SKIPS ffprobe on remote sources (json_validate.rs:191) and trusts
# our numbers verbatim, WE must probe. So this script ffprobes each remote URL
# and writes the measured duration. Wrong numbers here = the guide drifts and
# playout stutters, with no server-side correction. That's the whole point of
# probing at authoring time.
#
# Falls back to known-good durations if ffprobe isn't installed, so the harness
# still runs — but real Cinezoo must probe.
#
# Usage:  ./generate.sh
set -euo pipefail
cd "$(dirname "$0")"

BASE="https://commondatastorage.googleapis.com/gtv-videos-bucket/sample"

# Short clips so the loop cycles fast and you SEE as-run reports within a minute.
# title|url|fallback_seconds
CLIPS=(
  "For Bigger Blazes|$BASE/ForBiggerBlazes.mp4|15"
  "For Bigger Escapes|$BASE/ForBiggerEscapes.mp4|15"
  "For Bigger Fun|$BASE/ForBiggerFun.mp4|60"
  "For Bigger Joyrides|$BASE/ForBiggerJoyrides.mp4|15"
  "For Bigger Meltdowns|$BASE/ForBiggerMeltdowns.mp4|15"
)

probe() { # url -> duration seconds (float), or empty on failure
  command -v ffprobe >/dev/null 2>&1 || return 1
  ffprobe -v error -show_entries format=duration -of csv=p=0 "$1" 2>/dev/null
}

DATE="$(date +%F)"                        # 2026-07-21
DIR="$(date +%Y/%m)"                      # 2026/07
mkdir -p "$DIR"
OUT="$DIR/$DATE.json"

items=""
for row in "${CLIPS[@]}"; do
  IFS='|' read -r title url fallback <<<"$row"
  dur="$(probe "$url" || true)"
  if [[ -z "$dur" ]]; then
    echo "  ! ffprobe unavailable/failed for $title — using fallback ${fallback}s" >&2
    dur="$fallback"
  else
    printf '  probed %-22s %ss\n' "$title" "$dur" >&2
  fi
  # in=0 (never seek a remote source — it's slow), out=duration, playing=out-in.
  [[ -n "$items" ]] && items+=","
  items+=$(printf '\n    { "in": 0.0, "out": %s, "duration": %s, "source": "%s", "title": "%s" }' \
                  "$dur" "$dur" "$url" "$title")
done

cat > "$OUT" <<JSON
{
  "channel": "Phase 1 Test",
  "date": "$DATE",
  "program": [$items
  ]
}
JSON

echo "wrote $OUT"
echo "ffplayout will pull it from  http://<harness-host>:8085/$OUT"
