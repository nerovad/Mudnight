#!/bin/sh
# The ffplayout "external task": runs on every clip start.
#
# ffplayout invokes this as:   asrun.sh '<json>'
# where <json> is argv[1] — the SAME object GET /api/control/{id}/media/current
# returns (index, ingest, mode, elapsed, media{in,out,duration,source,title}).
#
# Hard rules from ffplayout (docs/external_tasks.md):
#   - fires on every non-skipped clip start
#   - the NEXT clip start KILLS this process if it's still running
#   - hard 30s timeout
# So: dispatch and exit. Never do work inline, never retry in-process.
#
# In production this POSTs to Cinezoo's POST /api/playout/asrun, authenticated
# with the channel's stream_key (same secret nginx-rtmp already validates).
# Here it just hits the local receiver container.

CINEZOO_ASRUN_URL="${CINEZOO_ASRUN_URL:-http://localhost:8099}"
CINEZOO_STREAM_KEY="${CINEZOO_STREAM_KEY:-phase1-demo-key}"

curl -fsS -m 5 -X POST "$CINEZOO_ASRUN_URL" \
  -H "Content-Type: application/json" \
  -H "X-Stream-Key: $CINEZOO_STREAM_KEY" \
  -d "$1" >/dev/null 2>&1 &
