# Linear Channels: Playout Architecture Spec

How Cinezoo runs 24/7 linear channels — a mix of **live-produced** channels and
**unattended scheduled** channels — while hosting the video itself and letting
owners manage their own programming through Cinezoo's UI.

Researched against ffplayout **v2.0.0-rc1** (master @ c76ba3d). There is no
OpenAPI spec; the Rust structs are the ground truth and the paths below were
read out of `backend/app/src/api/path.rs`.

> **Decisions baked in** (from design discussion, supersede earlier drafts):
> 1. **Cinezoo hosts the video**, server-side, not archive.org / creator URLs.
>    The URL model is documented in §10 as a clean later-swap, not the starting
>    point.
> 2. **Playout runs on Cinezoo's servers**, not owners' machines. Owners never
>    install anything. This makes ffplayout's GPL a non-issue (§15).
> 3. **Every channel is one of two modes, and the fleet is a real mix:**
>    `live` (existing OBS → nginx-rtmp path, unchanged) and `scheduled`
>    (ffplayout playout engine). A channel can switch modes over time.
> 4. **Nothing here breaks current videos.** Playout is *additive* — it feeds
>    the same nginx-rtmp tower the live path already uses.
> 5. Target fleet: **101 channels**. Cost model in §14.

---

## 1. The model

A channel is a slot on the tower. Two things can feed that slot, and the tower
doesn't care which:

```
  LIVE MODE (exists today, unchanged)
  OBS / vision mixer ─────────────────────────rtmp──▶ ┐
    (host cam, tape rolled in as media sources, band)  │
                                                        ├─▶ nginx-rtmp ─HLS─▶ viewers
  SCHEDULED MODE (new, additive)                        │      (the tower)
  ffplayout (Cinezoo-hosted, headless, API-driven) ─rtmp┘
    │  plays house-format files from Cinezoo storage
    │  loops the day's segment list
    └─ reports each clip start ──▶ Cinezoo as-run ──▶ guide / Now Playing
```

The tower — nginx-rtmp, `stream_key`, `on_publish` auth, hls.js, `HLS_BASE` —
is **exactly what you run today** and does not change. Scheduled mode just adds
a second kind of publisher: instead of a human with OBS, a Cinezoo-controlled
ffplayout process pushes into the same RTMP endpoint with the same stream key.

Everything Cinezoo owns:

| Concern | Owner |
|---|---|
| Programming UI (drag-drop scheduler) | **Cinezoo** |
| Video files (host + house-format transcode) | **Cinezoo** |
| The TV guide / Now Playing | **Cinezoo** |
| Playout engine (scheduled mode) | ffplayout, **run by Cinezoo**, driven by API |
| Live production (live mode) | The owner, in OBS — as today |

ffplayout is used purely as a playout engine. Its own web UI, its own scheduler,
its own auth are ignored — Cinezoo drives it over the API and owns the product
surface.

---

## 2. The two channel modes

`channels.playout_mode` is `'live'` or `'scheduled'`. The fleet is a real mix,
and a single channel can move between them over time.

### Live mode — your existing pipeline

An SNL-style show (live host → pre-recorded sketch → live band) is **one
continuous live broadcast**. The pre-recorded segments roll *inside* it as OBS
media sources; the operator cuts between live cameras and media. The tower sees
a single unbroken RTMP feed. This needs **nothing new** — it is the OBS → RTMP →
HLS path already in production.

Live mode is human-driven and real-time. It happens once, when someone produces
it. There is no schedule and no re-air — it is a live event.

### Scheduled mode — ffplayout

Unattended 24/7 programming: a channel's ordered segment list, looped, played by
a Cinezoo-hosted ffplayout process. No human at the controls. This is what the
rest of this doc specifies.

### The bridge: live → rerun

The one place the modes connect. **Record a live broadcast** and the recording
becomes a segment — a finished file with a known duration — that drops into the
channel's scheduled loop. Live show tonight → rerun tomorrow. This is the only
coherent reading of "read the length from the stream": a *finished* stream has a
length; a live one does not.

### Do you need seamless mid-playlist live preemption?

ffplayout *can* switch playlist→live→playlist seamlessly on one feed (§9). But
for the live-show case you generally **don't need it** — that show is produced
live in OBS, where the tape-rollin is a scene switch, not a playout concern. So
the common case is a **per-channel mode toggle**, not in-stream preemption. Keep
the seamless-switch capability in your pocket for the "24/7 channel that
occasionally cuts to live" case; don't build the product around it.

---

## 3. Cinezoo schema (migration `014_channel_segments.sql`)

```sql
-- A channel's ordered program list. Ordering is the source of truth;
-- air times are always derived, never stored.
CREATE TABLE IF NOT EXISTS channel_segments (
  id              BIGSERIAL PRIMARY KEY,
  channel_id      BIGINT NOT NULL REFERENCES channels(id) ON DELETE CASCADE,
  media_id        BIGINT NOT NULL REFERENCES channel_media(id),
  position        INT NOT NULL,          -- gapped (100, 200, 300) so a drag rewrites one row
  in_ms           BIGINT NOT NULL DEFAULT 0,   -- trim head (keep 0 in URL mode; see §10)
  out_ms          BIGINT NOT NULL,             -- trim tail; playing time = out - in
  category        TEXT,                        -- 'advertisement' is meaningful to the engine
  contribution_id BIGINT REFERENCES channel_contributions(id) ON DELETE SET NULL,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_segments_channel_position
  ON channel_segments(channel_id, position);

-- The hosted media catalogue. One row per uploaded master, after conform.
CREATE TABLE IF NOT EXISTS channel_media (
  id             BIGSERIAL PRIMARY KEY,
  channel_id     BIGINT NOT NULL REFERENCES channels(id) ON DELETE CASCADE,
  title          TEXT NOT NULL,
  storage_path   TEXT NOT NULL,          -- house-format file, relative to the channel storage root
  duration_ms    BIGINT NOT NULL,        -- ffprobe of the CONFORMED file (authoritative)
  source_kind    TEXT NOT NULL DEFAULT 'hosted'
                 CHECK (source_kind IN ('hosted', 'url')),   -- 'url' reserved for the §10 swap
  original_name  TEXT,
  conform_status TEXT NOT NULL DEFAULT 'pending'
                 CHECK (conform_status IN ('pending', 'ready', 'failed')),
  created_at     TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE channels
  ADD COLUMN IF NOT EXISTS playout_mode TEXT NOT NULL DEFAULT 'live'
    CHECK (playout_mode IN ('live', 'scheduled')),
  ADD COLUMN IF NOT EXISTS broadcast_day_start TIME NOT NULL DEFAULT '00:00',
  ADD COLUMN IF NOT EXISTS playout_token TEXT;   -- for the playlist-pull URL

-- As-run log: what actually aired, reported by the playout engine.
CREATE TABLE IF NOT EXISTS channel_asrun (
  id          BIGSERIAL PRIMARY KEY,
  channel_id  BIGINT NOT NULL REFERENCES channels(id) ON DELETE CASCADE,
  segment_id  BIGINT REFERENCES channel_segments(id) ON DELETE SET NULL,
  source      TEXT NOT NULL,
  title       TEXT,
  started_at  TIMESTAMPTZ NOT NULL,
  duration_ms BIGINT,
  is_ingest   BOOLEAN NOT NULL DEFAULT false,  -- true when live preempted the playlist
  raw         JSONB                            -- full engine payload, for debugging
);

CREATE INDEX IF NOT EXISTS idx_asrun_channel_started
  ON channel_asrun(channel_id, started_at DESC);
```

`channel_segments.media_id` points at a conformed `channel_media` row rather than
carrying a raw path — so a segment always references house-format media with a
trustworthy duration, and the same media can appear in the loop more than once.

Reordering inside a transaction can transiently duplicate positions. Use gapped
positions and rewrite only the moved row, or make the index
`DEFERRABLE INITIALLY DEFERRED`.

---

## 4. Media hosting + conform-on-ingest

This is the piece the "Cinezoo hosts the video" decision adds. It replaces the
old "sync the owner's disk over the API" flow entirely — Cinezoo *is* the media
manager now.

```
contributor/owner uploads master ──▶ Cinezoo storage (raw)
                                          │
                                     ffprobe (sanity) ─▶ reject if unreadable
                                          │
                                     CONFORM to house format (one-time ffmpeg)
                                          │  → channel_media.storage_path
                                          │  → channel_media.duration_ms  (ffprobe of the OUTPUT)
                                          └─ conform_status = 'ready'
```

**Conform to a single house format on ingest.** This is the highest-leverage
step in the whole system. Every master is transcoded once to one profile —
e.g. 720p (or 1080p) H.264, fixed GOP / keyframe interval, `+faststart`, AAC
audio, consistent sample rate. That one step buys:

- **Seamless clip joins.** Mismatched codecs/resolutions across uploads are
  exactly what makes stream-stitching stutter. Conformed media joins cleanly.
- **Trustworthy durations.** `duration_ms` is the ffprobe of the *conformed*
  file, done locally — instant and never wrong. The whole "Cinezoo must probe or
  the guide drifts" caveat from the URL model disappears.
- **No remote-origin risk.** Playout reads Cinezoo's own local/co-located disk,
  not 101 flaky origins. No CORS, no expiring URLs, no buffering gamble.

Conform is compute, but it's **one-time per file**, not the continuous per-channel
encoding that dominates cost (§14). Run it on a small worker or off-peak on the
playout boxes.

### Storage layout

ffplayout reads media by path under a per-channel storage root. Because playout
runs on Cinezoo infra, Cinezoo and ffplayout **share the filesystem** (same box,
or a shared/co-located volume). Cinezoo writes the conformed file to the
channel's storage root; the playlist references it by relative path. No file
transfer between them, no upload-over-API dance.

`channel_media.storage_path` is that relative path. It becomes the playlist
item's `source` (§5) directly.

### Uploads

Masters are large — use a **resumable upload** (tus or chunked multipart), not a
single POST. ffplayout's own chunked upload API exists but is irrelevant here:
Cinezoo controls the storage directly, so this is a plain Cinezoo upload endpoint
writing to the channel storage root, then enqueuing a conform job.

---

## 5. Playlist serialization

ffplayout's day playlist has exactly three serializable fields — `channel`,
`date`, `program`. Everything else in the Rust struct is `skip_serializing`.

```json
{
  "channel": "Channel 5",
  "date": "2026-07-20",
  "program": [
    { "in": 0.0, "out": 252.0, "duration": 252.0, "source": "sketches/cold-open.mp4", "title": "Cold Open" },
    { "in": 0.0, "out": 168.0, "duration": 168.0, "source": "sketches/news.mp4", "title": "The News" }
  ]
}
```

`source` is the `channel_media.storage_path` (a local path under the channel
storage root). Field notes that will bite otherwise:

- **`in` is serde-renamed** from the Rust field `seek`. The wire name is `in`.
- **Playing time is `out - in`**, not `duration`. `duration` is the full asset
  length. For an untrimmed clip, `in: 0` and `out == duration`.
- Values are **floats, in seconds**. Cinezoo stores ms; divide on the way out.
- Optional fields (`title`, `category`, `audio`, `custom_filter`) are omitted
  when empty, not sent as `""`.
- `channel` is a cosmetic label, *not* the channel ID.

### Expand the loop explicitly

ffplayout can loop a short playlist itself and fill the tail with fillers.
**Don't rely on that.** Have Cinezoo repeat the segment list in the `program`
array until the broadcast day is full, and emit it explicitly.

This is the whole point of the design: the guide and the playout read the
*identical array*. Air times in the guide are a cumulative sum over the same
list the engine plays. If Cinezoo emitted a short list and let the engine loop
it, Cinezoo would have to re-implement the engine's looping and tail-fill rules
to predict air times — two implementations of one rule, which is exactly the
drift we're designing out.

Eleven segments over 24h is a few hundred array entries. Trivial.

The final clip usually overruns the day boundary; ffplayout trims it
(`trim last clip, to get full 24 hours`). Cinezoo should render that item as
truncated in the guide rather than pretending it plays in full.

### Delivery endpoint

```
GET /api/channels/:slug/playlist/:year/:month/:date.json
```

**CORRECTED by Phase 5 integration (see §13):** the original design assumed
ffplayout *pulls* a playlist from an HTTP URL. It does not. Stock ffplayout v2
stores playlists locally and receives them over its API; only individual clip
`source`s may be remote URLs. So Cinezoo **pushes** instead:

```
login → configure the channel's stream output → POST the day playlist → control: start
```

- **`POST /api/playlist/{id}`** takes a full `{ channel, date, program }` JSON.
  It 409s if a playlist for that date already exists, so replace idempotently:
  `DELETE /api/playlist/{id}/{date}` then POST (`FfplayoutClient.pushPlaylist`).
- Playlist `source` **must be an absolute filesystem path**
  (`<media_storage_root>/<file>`) — a bare filename does not resolve against the
  channel storage. `buildDayPlaylist(..., storageRoot)` prefixes it.
- Re-push whenever `channels.schedule_rev` changes (a reorder/add/remove) so a
  running engine reloads the new order. `schedule_rev` and the internal
  `GET /api/playout/pl/:token/...` generator are still used — as the *source of
  the pushed JSON*, not as an endpoint the engine calls.
- The channel's stream **output is selected by `output.id`** (the row whose name
  is `stream`), not a free-form mode string; set its `stream_url` to the tower
  and enable the as-run `task` in the same `PUT /api/playout/config/{id}`.

---

## 6. As-run reporting

What makes "Now Playing" correct: the engine reports what it actually started,
rather than Cinezoo inferring it from timecodes. **Past = as-run (ground truth);
future = cumulative-sum projection over the segment list.**

ffplayout config keys: `task_enable: true`, `task_path: /opt/cinezoo/asrun.sh`
(nested as `task: { enable, path }` in `PlayoutConfig`; settable via
`PUT /api/playout/config/{id}` or directly in the DB).

Delivery is **argv, not stdin** (`utils/task_runner.rs:23`):

```rust
Command::new(task_path).arg(obj).kill_on_drop(true).spawn()
```

`obj` is the same JSON that `GET /api/control/{id}/media/current` returns:

```json
{
  "index": 3,
  "ingest": false,
  "mode": "playlist",
  "shift": 0.0,
  "elapsed": 12.34,
  "media": { "in": 0.0, "out": 252.0, "duration": 252.0, "category": "",
             "source": "sketches/cold-open.mp4", "title": "Cold Open" }
}
```

One payload shape covers both the push hook and the pull endpoint, so the parser
is written once.

```sh
#!/bin/sh
# /opt/cinezoo/asrun.sh — fire-and-forget. Must exit fast.
curl -fsS -m 5 -X POST "https://cinezoo.tv/api/playout/asrun" \
  -H "Content-Type: application/json" \
  -H "X-Stream-Key: $CINEZOO_STREAM_KEY" \
  -d "$1" >/dev/null 2>&1 &
```

Hard constraints from `docs/external_tasks.md`:

- Fires on **every non-skipped clip start**, one task per channel.
- Starting the next clip **kills a still-running previous task**.
- Hard **30-second timeout** (`TASK_TIMEOUT`).
- Must be executable by the ffplayout user.

So it must dispatch and exit. Never do work inline, never retry in-process.

### Receiving endpoint

```
POST /api/playout/asrun
```

Authenticate with the channel's existing `stream_key` via `X-Stream-Key`,
matching `rtmpController.verifyStreamKey`. Machine-to-machine — a user JWT is
wrong here. (Playout is co-located, so this can also be an internal token; the
stream key is convenient because it already exists per channel.)

Handler: resolve channel by stream key → match `media.source` back to a
`channel_segments` / `channel_media` row → insert `channel_asrun` with
`started_at = now()`. `ingest: true` means live has preempted the playlist —
record it and let the guide show "Live" instead of a scheduled title.

### Fallback if the task script can't be used

`POST /api/generate-uuid` then `GET /data/event/{id}?endpoint=playout&uuid=…`
gives the same data over SSE. Caveats: the UUID expires after 30 minutes and is
**bound to the requesting IP** — fragile behind NAT/proxy. Prefer the task
script.

---

## 7. Playout process lifecycle + on-demand encoding

Playout runs on Cinezoo infra as **one process per active scheduled channel**.
(ffplayout has an experimental multi-channel-in-one-instance mode; at 101
channels, prefer one process per channel — it's the un-flagged path and it's
what on-demand wants anyway.)

### Always-on vs on-demand

The single biggest cost lever (§14). A scheduled channel broadcasting 24/7 with
zero viewers still burns a full encoder if always-on.

- **Always-on** — every scheduled channel encodes continuously. Simplest.
  Correct for Phase 1/2. ~$1,000/mo compute for 101 channels 720p.
- **On-demand** — start the channel's playout process on the **first viewer**,
  and **seek to the schedule-computed offset** so it joins mid-programming as if
  it had been running; tear it down a grace period after the **last viewer**
  leaves. Idle channels then cost nothing.

The offset is computable because the schedule is deterministic:

```
resolve(channel, now):
  elapsed = (now − broadcast_day_start) mod total_loop_duration
  walk the segment list summing (out−in) until elapsed lands inside one
  return { segment, offset_into_segment }   // offset = ffplayout start seek
```

On-demand can cut compute **3–5×** on a young fleet with a long idle tail, at the
cost of orchestration complexity (process supervisor, viewer-count triggers off
the existing socket.io viewer counts, join-in-progress seek). **Prove the pipe
always-on first (Phase 1–2), then layer on-demand (Phase 5).**

### Control endpoints

| Method | Path | Body |
|---|---|---|
| POST | `/api/control/{id}/process` | `{"command": "status"｜"start"｜"stop"｜"restart"}` |
| GET | `/api/control/{id}/media/current` | now-playing + playout state |
| GET/PUT | `/api/playout/config/{id}` | full `PlayoutConfig` replace (GET, mutate, PUT) |

`{id}` is the integer channel ID; it is the only multi-channel addressing
mechanism — no header/query alternative. On-demand start/stop is
`POST /api/control/{id}/process`.

---

## 8. Live mode wiring

Live channels use the **existing** OBS → nginx-rtmp → HLS path with no changes.
When `playout_mode = 'live'`, Cinezoo does not run a playout process for that
channel; the owner publishes from OBS with the channel's `stream_key` exactly as
today. Nothing in this spec touches that flow — it is called out only so the two
modes form one coherent fleet.

---

## 9. Seamless in-stream live ingest (optional capability)

For the "scheduled channel that occasionally cuts to live" case, ffplayout runs
its own RTMP listener; when a publisher connects it switches playlist→live
**without interrupting output**, then returns to the playlist when the publisher
stops.

```
OBS ──rtmp://<playout-host>:1936/live/<key>──▶ ffplayout ──rtmp──▶ Cinezoo nginx-rtmp
```

Cinezoo sees one continuous publish and can't tell the difference. Auth on
ffplayout's ingest is weak (it compares app/stream name and kills on mismatch) —
firewall port 1936; don't expose it. The `ingest` flag in the as-run payload is
how Cinezoo knows live is active.

Treat this as a capability to enable per-channel, not the default. Most live
content is produced in OBS (§2), where this isn't needed.

---

## 10. Remote URL sources — the documented later-swap

Hosted-first is the starting point. But a segment's `source` can also be an
HTTP(S) URL, and ffplayout treats a URL and a local path almost identically —
so moving some/all media to creator-hosted URLs later is a **backend swap, not a
redesign**. It touches only §4 (ingest), not the scheduler, the guide, the
as-run loop, or the playout config. `channel_media.source_kind = 'url'` reserves
the seam.

If/when you enable it, the constraints (verified in source):

- `is_remote` matches `^(https?|rtmps?|rts?p|udp|tcp|srt)://`.
- **Remote items skip ffprobe entirely** (`json_validate.rs:191`) — the engine
  trusts your `duration`/`in`/`out` verbatim. So **Cinezoo must probe** at
  submission (`ffprobe -show_entries format=duration` reads a few KB of a
  faststart MP4 via range requests) and reject URLs that won't probe.
- **Avoid seeking** — keep `in: 0` on URL segments; a non-zero seek is slow.
- Despite the regex, **live protocols are not supported in playlists**
  (progressive HTTP(S) files only).
- Requires CORS-open, seekable, faststart origins — the reliability reasons
  hosted-first exists.

**Not YouTube.** No stable file URL (signed/expiring/throttled), ToS forbids
restreaming, and embeds give their player (with ads) rather than a poolable
stream — which also breaks seamless joins and as-run. YouTube is fine only as a
*preview link* inside a contribution.

---

## 11. What changes in Cinezoo

**Unchanged:** nginx-rtmp, `stream_key`, `on_publish` auth, hls.js playback,
`HLS_BASE`, and the entire live-mode path. Current videos keep playing.

**New endpoints — ✓ all built (Phases 2–4, branch `feat/media-pipeline`):**

| Method | Path | Auth | Status |
|---|---|---|---|
| GET | `/api/playout/pl/:token/:year/:month/:date.json` | `playout_token` | ✓ built — now the internal playlist **generator** behind the push (§5), not an endpoint ffplayout pulls |
| POST | `/api/playout/asrun` | `X-Stream-Key` | ✓ built |
| GET | `/api/channels/:slug/media` | JWT, owner | ✓ built |
| POST | `/api/channels/:slug/media` (streaming multipart → conform) | JWT, owner | ✓ built |
| DELETE | `/api/channels/:slug/media/:id` | JWT, owner | ✓ built |
| GET | `/api/channels/:slug/segments` | JWT, owner | ✓ built |
| POST | `/api/channels/:slug/segments` | JWT, owner | ✓ built |
| POST | `/api/channels/:slug/segments/reorder` (`{ordered_ids}`) | JWT, owner | ✓ built |
| PATCH | `/api/channels/:slug/segments/:id` (trim) | JWT, owner | ✓ built |
| DELETE | `/api/channels/:slug/segments/:id` | JWT, owner | ✓ built |

Note the playlist path landed as `/api/playout/pl/:token/...` (token in the
path, not `/channels/:slug/playlist/...`): ffplayout appends `/YYYY/MM/DD.json`
to its configured base URL, so the auth token must live in the base path, and it
doubles as the channel identifier. `playoutRoutes` is mounted at `/api/playout`
alongside `rtmpRoutes`.

**New service:** ✓ conform worker (`services/conform.ts`, ffmpeg → house format)
and playlist generation (`services/playlist.ts`). Still to build: the playout
supervisor (start/stop ffplayout processes, always-on now, on-demand in Phase 5).

**Resumable upload** was descoped to streaming multipart for v1 (see §4); tus is
a later upgrade.

**Rewritten:** `getChannelSchedule` in `channelController.ts:836`. Today it
expands recurrence from `scheduled_at` timestamps and falls back to a hardcoded
1-hour duration. It becomes: read as-run for now-playing (ground truth),
cumulative-sum the segment list for up-next (projection).

`NowPlayingWidget.tsx` polls `/api/channels/:id/schedule` every 30s and only
needs `now_playing` / `up_next`. **Keep that response shape** — the widget needs
no changes; only its accuracy improves.

**Contributions:** accepting a pitch becomes "append a `channel_segments` row"
referencing conformed media, instead of writing `channel_schedule` with an
absolute timestamp. This removes the `ON CONFLICT (channel_id, scheduled_at)`
overwrite hazard. `contribution_id` carries the credit forward as it does now.
Fix while here: `ContributionsWidget.tsx:140` populates its film picker from
`/api/films/mine`, which queries `user_profile_film_links` — a different table
with an unrelated ID sequence from `films`, so an existing-film pick sends the
wrong id.

---

## 12. Gotchas

Each is a silent failure rather than an error:

1. **`out - in`, not `duration`** for playing time. Getting it wrong drifts the
   guide.
2. **`in` vs `seek`.** Wire name is `in`; the Rust field is `seek`.
3. **`Last-Modified` must be correct** or the engine won't reload after a
   reorder.
4. **Conform, then probe.** `duration_ms` must be the ffprobe of the *conformed*
   output, not the raw master — re-encoding can change duration slightly.
5. **Task script is killed** when the next clip starts. Fire and forget.
6. **SSE UUID is IP-bound** and expires in 30 minutes.
7. **Expand the loop explicitly** — don't let the engine loop a short list, or
   the guide has to re-derive the engine's rules.
8. **On-demand join must seek** to `resolve(now).offset`, or a channel restarts
   from the top of the loop whenever the first viewer joins.
9. **409 on identical playlist** in push mode (`write_playlist`) — N/A in pull
   mode, noted in case a push path is ever added.
10. **URL-mode durations are unvalidated** (§10) — only relevant after the swap.

---

## 13. Phasing

**✓ Phase 1 — prove the pipe. DONE.** The one real risk — whether a *continuous*
push segments cleanly into nginx-rtmp → HLS — was retired with the harness in
[`docs/phase1/`](phase1/README.md). Verified on-machine: an ffmpeg stand-in
looping four clips produced clean live HLS with **no `EXT-X-DISCONTINUITY` at
clip boundaries** (only the stream-start marker), uniform 4s segments unaligned
to the 5s clips, ffprobe-playable throughout.

**✓ Phase 2 — as-run. DONE.** `POST /api/playout/asrun` (auth `X-Stream-Key`) →
`channel_asrun` (migration 014). `getChannelSchedule` rewritten to read as-run as
ground truth for `now_playing`, falling back to `channel_schedule` for legacy /
live channels; response shape unchanged so `NowPlayingWidget` needs no edits.

**✓ Phase 3 — hosting + conform. DONE.** `POST /api/channels/:slug/media`
streams a master to per-channel storage; `services/conform.ts` transcodes to the
house format (1280×720, 30fps, H.264, GOP 60, faststart, AAC) and probes the
**conformed output** for an authoritative duration. Verified: a vertical
480×854 master → uniform 1280×720, duration measured from the output (7012ms vs
the master's 7000).

**✓ Phase 4 — the scheduler. DONE.** `channel_segments` CRUD + a `reorder` that
rewrites gapped positions via a two-phase update (park negative, then finals) so
the non-deferrable unique index never transiently collides (verified). Playlist
generation (`services/playlist.ts`) expands the loop to fill 24h (verified: 417
items, correct `in`/`out`/`duration`, trims, categories). `GET /api/playout/pl/
:token/...` serves it with `Last-Modified` from `channels.schedule_rev`
(migration 015, bumped on every mutation) + `If-Modified-Since` → 304. The
`SchedulerWidget` (owner-only, from the channel Menu) is the drag-drop UI:
media library + upload with conform polling on the left, reorderable timeline
(block height ∝ duration) on the right.

**Contributions rewiring** (accepted pitch → append a `channel_segments` row)
and the `ContributionsWidget` `film_id` fix remain open follow-ups.

**→ Phase 5 — the real ffplayout + on-demand encoding.**
1. **Integration — DONE.** Ran a real ffplayout v2.0.0-rc5 against channel-12
   (id 63) end-to-end and proved the whole loop: Cinezoo scheduler → ffplayout
   playing our ordered segment loop → RTMP → nginx-rtmp tower → HLS; as-run
   firing per clip into `channel_asrun`; "Now Playing" reflecting the as-run
   ground truth; wall-clock join mid-loop; clean clip boundaries. The compiled
   `FfplayoutApiDriver` (not hand calls) drove the verified start.

   **Findings the real engine forced (all fixed):**
   - **Push, not pull.** Playlists are POSTed, not fetched — see §5.
     `FfplayoutClient` + `FfplayoutApiDriver`; `getPlaylist`/`schedule_rev` are
     now the internal generator behind the push, not a pulled endpoint.
   - **Absolute sources.** `buildDayPlaylist(..., storageRoot)` emits
     `<media_storage_root>/<file>`; a bare filename won't play.
   - **As-run attribution.** ffplayout reports the absolute `source`;
     `recordAsRun` now matches `channel_media.storage_path` by basename, so
     `segment_id` resolves again (verified: rows attributed 2/2/3).
   - **Channel lifecycle.** ffplayout's in-memory manager only holds channels
     created via `POST /api/channel`; a process restart empties it, and the
     active output is chosen by `output.id`. The supervisor/provisioner must
     register + configure the channel through the API, not assume DB rows.
   - **FFmpeg pin.** The prebuilt binary needs FFmpeg 7; production `.deb`
     handles it, dev used a Debian-trixie container wrapper.
2. **On-demand encoding** — a playout supervisor that starts a channel's engine
   on the first viewer (ffplayout clock-syncs the join) and tears down after the
   last viewer leaves. Built (`onDemandPlayout.ts`, env-gated, default-off) and
   now wired to the push-based `FfplayoutApiDriver`; the remaining work is the
   process-per-channel orchestration (spin-up + per-channel base URL) implied by
   the cost model (§14).

Everything above is built and unit/integration-tested; Phase 5 part 1 is proven
against a live ffplayout process.

---

## 14. Cost model (101 channels)

Compute is the driver — not storage, not bandwidth.

| Cost | Driver | Estimate |
|---|---|---|
| **Compute (always-on)** | ffplayout ≈ 4 threads + 3 GB per 720p channel → ~404 threads | **~$1,000–1,100/mo** |
| **Compute (on-demand)** | scales with peak *concurrent active* channels | **~$400–700/mo** early |
| **Egress** | ~1.1 GB per viewer-hour @ 720p, via CDN | **viewership-dependent** |
| **Storage** | hosted catalogue, ~200 GB–3 TB early | **~$0–20/mo** |
| **Conform** | one-time ffmpeg per upload | negligible ongoing |
| **Ingest** | pulling/serving, bundled on dedicated | ~$0 |

- **Compute:** a Hetzner AX162 is 96 threads / 256 GB for €199/mo. ~404 threads
  ≈ 5 boxes ≈ ~€1,000/mo always-on. 480p roughly halves it. The 4-thread figure
  is ffplayout's conservative rec; real 720p x264 often runs in 1–2 cores.
- **Egress — use a CDN, not cloud egress (10× difference).** Bunny $0.005–0.01/GB
  vs cloud $0.05–0.09/GB. ~20 concurrent avg ≈ $80–160/mo; ~100 ≈ $400–800/mo;
  ~500 ≈ $2,000–4,000/mo. Grows with viewership, i.e. with whatever funds it.
- **Storage is a rounding error** at this catalogue size — it fits on the NVMe
  the compute boxes already ship with.

**Levers, in priority order:** on-demand encoding (biggest) → bare metal over
cloud vCPU (~5×) → CDN over cloud egress (~10×) → 480p over 720p (~2×).

**Bottom line:** ~$1,200–1,500/mo all-in early (always-on); ~$400–700/mo with
on-demand. Four figures, not five.

Pricing sources: [Hetzner AX162](https://www.hetzner.com/pressroom/new-ax162/) ·
[Bunny pricing](https://swarmify.com/blog/bunny-stream-review/).

---

## 15. Decision: ffplayout vs build-your-own

**Use ffplayout now. Build your own only if/when you outgrow it — an informed,
later decision.**

The hard parts of playout are the unsexy ones ffplayout has already solved:
24/7 encoder stability, recovering from a corrupt file without a black gap, no
audio/PTS drift across clip boundaries, conform-on-the-fly, loop/trim/filler,
and seamless playlist↔live switching. Rebuilding those to reach the *starting
line* is months of subtle ffmpeg work. Adopting ffplayout lets you prove the
actual product — owners scheduling their own channels, hosted video, an accurate
guide — first.

Build-your-own becomes rational once you've hit specific limits (multi-channel
scale, on-demand orchestration you want tighter control over) and know exactly
what to build and why. Adopt-then-maybe-replace beats build-from-scratch-now.

Two things the server-side + hosted decisions already simplified:

- **GPL-3.0 is a non-issue.** You run ffplayout on your own servers and never
  distribute the binary. It would only attach if you shipped it to owners in an
  installer — which the hosted model eliminates. Talking to it over HTTP and
  passing JSON via argv is arm's-length process separation, not a combined work
  (same as any app shelling out to ffmpeg). *(Not legal advice.)*
- **The install-button problem disappears.** Owners install nothing; playout is
  yours to operate.

ffplayout ships its own playlist-editing web UI, which overlaps with Cinezoo's
scheduler. Drive it through the API / pull-mode and treat its frontend as an
admin/debug surface, not part of the product.

---

Sources: [docs/api.md](https://github.com/ffplayout/ffplayout/blob/master/docs/api.md) ·
[external_tasks.md](https://github.com/ffplayout/ffplayout/blob/master/docs/external_tasks.md) ·
[remote_source.md](https://github.com/ffplayout/ffplayout/blob/master/docs/remote_source.md) ·
[live_ingest.md](https://github.com/ffplayout/ffplayout/blob/master/docs/live_ingest.md)
