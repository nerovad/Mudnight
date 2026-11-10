#!/usr/bin/env python3
"""Stand-in for Cinezoo's POST /api/playout/asrun.

Prints each as-run report ffplayout sends when a clip starts. This is the
"Now Playing is REPORTED, not predicted" half of the design made visible:
whatever scrolls past here is ground truth about what actually aired.

In the real backend this handler would:
  1. resolve the channel by X-Stream-Key
  2. match media.source back to a channel_segments row
  3. insert a channel_asrun row (started_at = now())
  4. if ingest=true, mark the channel "Live" instead of a scheduled title
"""
import json
from datetime import datetime, timezone
from http.server import BaseHTTPRequestHandler, HTTPServer

PORT = 8099


class Handler(BaseHTTPRequestHandler):
    def do_POST(self):
        length = int(self.headers.get("Content-Length", 0))
        raw = self.rfile.read(length)
        self.send_response(204)
        self.end_headers()

        key = self.headers.get("X-Stream-Key", "?")
        now = datetime.now(timezone.utc).strftime("%H:%M:%S")
        try:
            data = json.loads(raw)
            media = data.get("media", {})
            title = media.get("title") or media.get("source", "?")
            live = " [LIVE INGEST]" if data.get("ingest") else ""
            play = float(media.get("out", 0)) - float(media.get("in", 0))
            print(f"{now}  key={key}  #{data.get('index','?')}  "
                  f"{title}  ({play:.0f}s){live}", flush=True)
        except (ValueError, TypeError):
            print(f"{now}  key={key}  <unparseable> {raw!r}", flush=True)

    def log_message(self, *_):  # silence default access logging
        pass


if __name__ == "__main__":
    print(f"as-run receiver listening on :{PORT} — waiting for clip starts...",
          flush=True)
    HTTPServer(("0.0.0.0", PORT), Handler).serve_forever()
