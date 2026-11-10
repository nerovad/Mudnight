# Phase 1 harness — prove the pipe

**The one question this answers:** does a *continuous* playout push segment
cleanly into nginx-rtmp → HLS, with clean clip boundaries? Everything else in
the [playout plan](../ffplayout-adapter.md) rides on "yes." This harness gets
you there touching **no production code and no Cinezoo backend**.

There are two ways to run it, cheapest first:

- **Tower test** (`tower-test.sh`) — an ffmpeg loop stands in for the playout
  push. No ffplayout, no network. Proves the risky half — the nginx-rtmp → HLS
  segmentation — in about a minute. **Start here.**
- **Full test** — a real ffplayout pulling a playlist from the harness and
  reporting as-run. Proves pull-mode, the config, and the as-run loop too.
  Needs ffplayout installed (see below).

> **Server-side note.** In the shipped architecture Cinezoo *hosts* the video
> and runs ffplayout *on its own servers* — owners install nothing. So the
> `edge`, `playlists`, and `asrun` containers here stand in for pieces Cinezoo
> owns (the streaming tower, the playlist endpoint, `POST /api/playout/asrun`),
> and ffplayout is the engine Cinezoo drives. Nothing in the plan asks an owner
> to run a station on their laptop. See [the spec](../ffplayout-adapter.md) §1.

```
  playlists (:8085)                 ffplayout / ffmpeg             edge (:1935 in, :8088 out)
  ─────────────────                 ──────────────────             ──────────────────────────
  today's playlist  ──HTTP pull──▶  continuous push   ──RTMP──▶    nginx-rtmp ──HLS──▶ watch.html
  (static JSON)      Last-Modified   loops the list                 segments per stream
                                          │
                                     on each clip start
                                          │  argv[1] = now-playing JSON
                                     asrun.sh ──POST──▶ asrun (:8099)  "what actually aired"
```

---

## Prerequisites

- Docker + docker compose
- ffmpeg / ffprobe on the host (the tower test uses them; they also generate
  the local test clips — no network needed)
- Internet only for the *optional* remote-sample playlist (`generate.sh`)

Ports used on the host: **1935** (RTMP in), **8088** (HLS out, mirrors
production's `cinezoo.tv:8088`), **8085** (playlist server), **8099** (as-run
receiver). Free them first if something else is bound there.

---

# A. Tower test — the fast path (recommended first)

Proves clean continuous-push → HLS with nothing but the edge and ffmpeg.

```bash
cd docs/phase1
chmod +x tower-test.sh verify.sh
docker compose up -d --build edge        # just the streaming tower
./tower-test.sh phase1-demo-key 60 &     # push a looped clip reel for 60s
sleep 12                                  # let HLS fill
./verify.sh phase1-demo-key               # automated pass/fail
```

`tower-test.sh` generates four short 720p clips locally (labelled SEGMENT-1..4,
one house format), then pushes them on an infinite loop as a single continuous
encoder — transport-identical to what ffplayout does. `verify.sh` checks the
manifest has segments, is live (advancing), carries **no** `EXT-X-DISCONTINUITY`
at clip boundaries, and is ffprobe-playable.

Watch it: open `watch.html` — the coloured SEGMENT clips cycle. The boundary
between clips should be a clean cut, no stall.

**Pass = clean live HLS.** That's the transport risk retired. If boundaries
stutter or discontinuity tags appear here, that's the finding — cheap, before
any scheduler exists.

---

# B. Full test — real ffplayout end-to-end

Adds pull-mode playlists and as-run reporting on top.

## B1 — bring up all three harness pieces

```bash
cd docs/phase1
chmod +x playlists/generate.sh asrun/asrun.sh
./playlists/generate.sh          # writes playlists/YYYY/MM/today.json (probes durations)
docker compose up -d --build     # edge + playlists + asrun
docker compose logs -f asrun     # leave running — your as-run monitor
```

`generate.sh` builds a playlist of remote sample clips (needs internet). To stay
offline, point the playlist at the local clips `tower-test.sh` produced under
`media/` instead.

## B2 — install ffplayout (Cinezoo runs this; here you run it locally to test)

ffplayout is server software. For a local test box:

1. Debian/Ubuntu: grab the latest `.deb` from
   <https://github.com/ffplayout/ffplayout/releases/latest>,
   `sudo apt install /tmp/ffplayout_<VERSION>_amd64.deb`.
   Other distros (Arch, etc.): use the release `tar.gz` binary, or build the
   container from the ffplayout repo's `docker/debian.Dockerfile`.
2. Ensure FFmpeg 7.0–8.1 runtime libs are present (`ffmpeg -version`).
3. Start it; open <http://localhost:8787>; complete first-time setup (creates
   the admin + channel id `1`).

## B3 — point ffplayout at the harness

Three settings (ffplayout web UI, channel 1 — or script them via
`PUT /api/playout/config/1` + `PATCH /api/channel/1`):

| In the UI | Config key | Value |
|---|---|---|
| Playlist source (as a URL) | `channel.playlists` | `http://localhost:8085` |
| Output → **Stream** | `output` | RTMP to `rtmp://localhost:1935/live/phase1-demo-key` |
| Processing → **Task** | `task.enable` / `task.path` | on / absolute path to `docs/phase1/asrun/asrun.sh` |

Notes:
- **Playlist as a URL is pull mode** — the heart of the design. ffplayout fetches
  `http://localhost:8085/YYYY/MM/YYYY-MM-DD.json` and reloads when
  `Last-Modified` changes. No POST, no login, no daemon.
- Output stream key `phase1-demo-key` → HLS at `/hls/phase1-demo-key/index.m3u8`,
  the URL already in `watch.html`.
- ffplayout in a container while the harness is on the host? Replace `localhost`
  with `host.docker.internal` in all three, and set
  `CINEZOO_ASRUN_URL=http://host.docker.internal:8099` for the task.
- The ffplayout user must be able to execute `asrun.sh` (`chmod +x`).

Start playout (UI play, or `POST /api/control/1/process {"command":"start"}`).

## B4 — watch it work

- **Viewer output:** `watch.html` plays and loops the clips (~15–30s to fill).
- **As-run:** the `logs -f asrun` terminal prints a line per clip start:
  ```
  14:32:04  key=phase1-demo-key  #0  For Bigger Blazes  (15s)
  14:32:19  key=phase1-demo-key  #1  For Bigger Escapes  (15s)
  ```
- **Seamless live ingest (optional):** point OBS at ffplayout's own ingest
  listener `rtmp://<host>:1936/live/<key>`. Output switches to OBS without a
  drop; the next as-run line shows `[LIVE INGEST]`; stop OBS → back to playlist.
  (This is the *optional* seamless-preemption capability — most live content is
  produced in OBS as its own channel; see spec §2, §9.)

---

## What "pass" looks like

1. HLS **plays and loops** smoothly (`watch.html`).
2. Clip boundaries are **clean** — no viewer-visible stall, no discontinuity
   tags. *(The tower test checks this automatically.)*
3. (Full test) The as-run monitor prints one accurate line per clip start.
4. (Full test) Editing the playlist makes ffplayout reload within its poll
   interval — no restart.

Tower test green retires the transport risk. Full test green means Phase 2
(real `POST /api/playout/asrun` + rewiring `getChannelSchedule`) is worth
building.

---

## Teardown

```bash
docker compose down          # stops edge + playlists + asrun
# kill the tower-test push if still running; stop/remove ffplayout if installed
```

## Going against real production instead of the local edge

Set the push target to `rtmp://cinezoo.tv:1935/live/<a-test-channel-stream_key>`
and point `watch.html` at `https://cinezoo.tv:8088/hls/<that-key>/index.m3u8`.
Use a throwaway/test channel only — you're putting the clip reel on real air.
