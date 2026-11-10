#!/bin/sh
# Phase 5 as-run task — the REAL one, pointed at a live Cinezoo channel.
#
# ffplayout runs this on every clip start with the now-playing JSON as argv[1]
# (the same object GET /api/control/{id}/media/current returns). It POSTs that to
# Cinezoo's /api/playout/asrun, authenticated with the channel's stream_key.
#
# Both values come from the provisioning config
# (POST /api/channels/:slug/playout/provision):
#   CINEZOO_ASRUN_URL   = config.asrun_url
#   CINEZOO_STREAM_KEY  = config.stream_key
# Export them in the ffplayout service environment.
#
# Hard rules (docs/external_tasks.md): fires on every non-skipped clip start,
# the next clip start KILLS a still-running task, 30s timeout. So: dispatch and
# exit — never block, never retry in-process.

: "${CINEZOO_ASRUN_URL:?set CINEZOO_ASRUN_URL to config.asrun_url}"
: "${CINEZOO_STREAM_KEY:?set CINEZOO_STREAM_KEY to config.stream_key}"

curl -fsS -m 5 -X POST "$CINEZOO_ASRUN_URL" \
  -H "Content-Type: application/json" \
  -H "X-Stream-Key: $CINEZOO_STREAM_KEY" \
  -d "$1" >/dev/null 2>&1 &
