# Phase 5 — real ffplayout integration

**The one seam nothing above has exercised.** Phases 1–4 are built and tested,
but every test so far used an *ffmpeg stand-in* for playout (Phase 1) or a
throwaway Postgres (Phases 2–4). This step points a **real ffplayout** at a
**real Cinezoo channel** and confirms the whole loop end to end:

```
  Cinezoo scheduler ──playlist pull──▶ ffplayout ──RTMP──▶ nginx-rtmp ──HLS──▶ viewers
        (Phase 4)                          │                                       │
        ▲                                  └── as-run on each clip ──▶ Cinezoo ─────┘
        │                                           (Phase 2)         Now Playing
   drag-drop UI                                                       (accurate)
```

If this works, the linear-channel product is real. This is also the last thing
that must pass before the on-demand supervisor (part 2 of Phase 5) is worth
building.

---

## Prerequisites

1. **Migrations applied** through `015` (`npm run migrate --workspace=backend`).
2. **A channel with content** — upload masters and build a loop in the Scheduler
   widget (Phase 3/4), so the playlist isn't empty. Confirm:
   `GET /api/channels/:slug/segments` returns ready segments.
3. **ffplayout installed** on a box that can reach Cinezoo and read the media
   volume (`config.media_storage_root`). See `docs/ffplayout-adapter.md` §15.
4. **Env on the Cinezoo backend** so the emitted config has correct URLs:
   - `PUBLIC_BASE_URL` (e.g. `https://cinezoo.tv`) — where the API is reachable
   - `RTMP_INGEST_URL` (e.g. `rtmp://cinezoo.tv:1935/live`) — the tower
   - `MEDIA_ROOT` — the shared media volume (same one ffplayout reads)

---

## Step 1 — provision the channel

Turns the channel into a scheduled channel and prints the engine config.

```bash
CINEZOO_API=https://cinezoo.tv JWT=<owner-token> ./provision.sh <slug>
```

Response:

```json
{
  "config": {
    "channel_id": 5,
    "playout_mode": "scheduled",
    "playlist_url": "https://cinezoo.tv/api/playout/pl/<token>",
    "rtmp_output": "rtmp://cinezoo.tv:1935/live/<stream_key>",
    "media_storage_root": "/srv/cinezoo/media/5",
    "asrun_url": "https://cinezoo.tv/api/playout/asrun",
    "stream_key": "<stream_key>"
  }
}
```

`playout_token` is minted on first call and reused after; re-running is safe.

Sanity-check the playlist is served (the engine will fetch exactly this shape):

```bash
curl -s "https://cinezoo.tv/api/playout/pl/<token>/$(date +%Y/%m/%F).json" | head
# expect { "channel": "...", "date": "YYYY-MM-DD", "program": [ ... ] }
```

---

## Step 2 — configure ffplayout with those values

In ffplayout (web UI on `:8787`, or `PUT /api/playout/config/{id}` + the channel
record). Map the config fields:

| ffplayout setting | value |
|---|---|
| Channel **Playlist** (as a URL) | `config.playlist_url` |
| Channel **Storage** | `config.media_storage_root` |
| **Output** → Stream | `config.rtmp_output` |
| Processing → **Task**: enable | on |
| Processing → **Task**: path | absolute path to `docs/phase5/asrun.sh` |

And in the ffplayout service environment (so the task script can reach Cinezoo):

```
CINEZOO_ASRUN_URL=<config.asrun_url>
CINEZOO_STREAM_KEY=<config.stream_key>
```

`chmod +x docs/phase5/asrun.sh` and make sure the ffplayout service user can
execute it.

Pull mode means the engine fetches the playlist over HTTP and reloads when
`Last-Modified` changes — so a drag-to-reorder in the Scheduler widget takes
effect on the next poll, no restart.

---

## Step 3 — start and verify end to end

Start playout (UI, or `POST /api/control/{id}/process {"command":"start"}`).

Verification checklist:

1. **Playlist pull** — ffplayout logs show it fetching
   `/api/playout/pl/<token>/…json`; Cinezoo logs show 200s (then 304s while
   unchanged).
2. **On air** — open the channel on Cinezoo; the HLS plays the scheduled loop
   (same nginx-rtmp/hls.js path as a live channel — nothing changed there).
3. **Clean boundaries** — clip changes don't stall (Phase 1 proved the
   transport; this confirms it with a real engine).
4. **As-run fills** — `SELECT source, title, started_at, is_ingest FROM
   channel_asrun WHERE channel_id = <id> ORDER BY started_at DESC LIMIT 5;`
   shows a row per clip start.
5. **Now Playing is correct** — the NowPlayingWidget reflects what the as-run log
   says is airing (ground truth, not a timecode guess).
6. **Reorder propagates** — drag a segment in the Scheduler; within the poll
   interval the engine reloads and the new order airs.
7. **Live preempt (optional)** — push OBS to ffplayout's own ingest; the next
   as-run row shows `is_ingest = true` and the guide can show "Live".

If all pass, Phase 5 part 1 is done and the architecture is proven with real
software, not stand-ins.

---

## What's next in Phase 5

**On-demand encoding — the supervisor.** Once a real engine runs cleanly, the
cost optimization (§14 of the spec): a service that starts a channel's ffplayout
on the first viewer, seeks to `resolve(now).offset` so it joins mid-loop, and
tears it down after the last viewer leaves — so idle channels cost nothing. That
turns "101 always-on encoders" into "encode only what's being watched." It's the
larger build and only pays off once the fleet is real; this integration is the
gate before it.
