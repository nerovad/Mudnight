#!/usr/bin/env bash
# Provision a channel for scheduled playout and print the ffplayout config.
#
# Usage:
#   CINEZOO_API=https://cinezoo.tv JWT=<owner-jwt> ./provision.sh <slug>
#
# Mints the channel's playout_token (if absent), sets playout_mode='scheduled',
# and returns the engine config: playlist_url, rtmp_output, media_storage_root,
# asrun_url, stream_key. Owner JWT required.
set -euo pipefail

API="${CINEZOO_API:-http://localhost:5000}"
SLUG="${1:?usage: provision.sh <channel-slug>}"
: "${JWT:?set JWT to an owner access token}"

echo "Provisioning '$SLUG' at $API ..." >&2
curl -fsS -X POST "$API/api/channels/$SLUG/playout/provision" \
  -H "Authorization: Bearer $JWT" \
  -H "Content-Type: application/json" \
  | { command -v jq >/dev/null 2>&1 && jq . || cat; }

cat >&2 <<'NEXT'

Next: configure ffplayout for this channel with the values above —
  playlists       <- playlist_url        (engine appends /YYYY/MM/YYYY-MM-DD.json)
  output (stream) <- rtmp_output
  storage         <- media_storage_root
  task.enable=true, task.path=<abs path to docs/phase5/asrun.sh>
  and export CINEZOO_ASRUN_URL=asrun_url, CINEZOO_STREAM_KEY=stream_key
See docs/phase5/README.md.
NEXT
