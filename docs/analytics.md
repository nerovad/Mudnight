# Analytics

Self-hosted [Umami](https://umami.is) on the Cinezoo frontend. Cookieless, no
personal data, no consent banner required, and the data stays on our own box.

## What's instrumented

| Signal | Type | Fires when |
| --- | --- | --- |
| pageview | built-in | A viewer stays on a route for 3s (see *Dwell threshold*) |
| `heartbeat` | custom | Every 60s the tab is visible on a channel route. Payload: `{ channel }` |
| `channel-change` | custom | Channel flip. Payload: `{ from, to, dwellSeconds }` |

Code lives in `frontend/src/analytics/`:

- `umami.ts` — script injection and the `track` / `trackPageview` wrappers
- `hooks.ts` — `usePageviews`, `useViewingHeartbeat`, `useChannelDwell`

Mount points: `main.tsx` (init), `App.tsx` (`RouteTracker`), and
`VideoPlayer.tsx` (heartbeat + dwell).

### Dwell threshold

Every channel flip is a `navigate(..., { replace: true })`, so Umami's default
auto-tracker would log a pageview per flip — one pass up the dial would look
like ~100 views. Auto-tracking is therefore disabled (`data-auto-track="false"`)
and pageviews are sent by hand only after a viewer settles for
`PAGEVIEW_DWELL_MS` (3s). Flip-throughs still show up as `channel-change`
events, which is where they belong.

### Why heartbeats

Umami's realtime panel only ever shows *right now*. Counting heartbeats gives
the historical shape, and one heartbeat is exactly one viewer-minute:

```
viewer-hours over a period   = heartbeats in that period / 60
average concurrent viewers   = heartbeats in an hour / 60
```

Average concurrent viewers is the number a sponsor actually responds to,
because it's the one that sounds like a broadcast audience.

## Setup

### 1. Bring up Umami

On the server, from the repo root:

```bash
export UMAMI_DB_PASSWORD=$(openssl rand -base64 24)
export UMAMI_APP_SECRET=$(openssl rand -base64 32)
# persist both in your shell profile or an env file — compose needs them on every up
docker compose -f docker-compose.umami.yml up -d
```

Log in at `http://127.0.0.1:3000` with `admin` / `umami`, **change the
password**, then add a website for `cinezoo.tv`. Copy the website ID from
Settings → Websites → Edit.

### 2. Reverse proxy it

Umami binds to localhost only. Give it a hostname on the box that already
terminates TLS:

```nginx
server {
    listen 443 ssl;
    server_name stats.cinezoo.tv;

    # ... existing ssl_certificate directives ...

    location / {
        proxy_pass http://127.0.0.1:3000;
        proxy_set_header Host              $host;
        proxy_set_header X-Real-IP         $remote_addr;
        proxy_set_header X-Forwarded-For   $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

### 3. Point the frontend at it

Create `frontend/.env.production` on the server (see `frontend/.env.example`):

```
VITE_API_URL=...
VITE_SOCKET_URL=...
VITE_UMAMI_SCRIPT_URL=https://stats.cinezoo.tv/script.js
VITE_UMAMI_WEBSITE_ID=<uuid from step 1>
```

Vite inlines these at build time, so `./deploy.sh` picks them up on the next
build. The file is not in git — if you'd rather it were, note that both values
are public (they ship in the client bundle), so there's no secret to leak.

Without both vars set, `analyticsEnabled` is false: no script request, no
events, every hook a no-op. That's the correct state for local dev.

## Getting the numbers out

The dashboard covers uniques, sessions, referrers, and countries. The
viewing metrics need SQL. Against the Umami database:

```bash
docker exec -it umami-db psql -U umami -d umami
```

These are written for Umami v2's schema — check the column names if you're on a
different major version.

**Viewer-hours and average concurrency, last 30 days:**

```sql
SELECT count(*) / 60.0                        AS viewer_hours,
       count(*) / 60.0 / (30 * 24)            AS avg_concurrent_viewers
FROM   website_event
WHERE  event_name = 'heartbeat'
AND    created_at >= now() - interval '30 days';
```

**Concurrency by hour of day** — this is what tells a sponsor when their
message is seen, and it's usually far more flattering than the flat average:

```sql
SELECT extract(hour FROM created_at) AS hour_utc,
       count(*) / 60.0 / 30          AS avg_concurrent_viewers
FROM   website_event
WHERE  event_name = 'heartbeat'
AND    created_at >= now() - interval '30 days'
GROUP  BY 1
ORDER  BY 1;
```

**Watch time per channel** — the input to per-channel sponsorship pricing:

```sql
SELECT ed.string_value        AS channel,
       count(*) / 60.0        AS viewer_hours
FROM   website_event we
JOIN   event_data ed ON ed.website_event_id = we.event_id
WHERE  we.event_name = 'heartbeat'
AND    ed.data_key   = 'channel'
AND    we.created_at >= now() - interval '30 days'
GROUP  BY 1
ORDER  BY 2 DESC;
```

**Stickiness per channel** — median dwell separates destinations from
pass-throughs. A channel with high flips and low dwell is not sponsorable:

```sql
SELECT ed_to.string_value                                           AS channel,
       count(*)                                                     AS arrivals,
       percentile_cont(0.5) WITHIN GROUP (ORDER BY ed_dwell.number_value) AS median_dwell_seconds
FROM   website_event we
JOIN   event_data ed_to    ON ed_to.website_event_id = we.event_id
                          AND ed_to.data_key = 'to'
JOIN   event_data ed_dwell ON ed_dwell.website_event_id = we.event_id
                          AND ed_dwell.data_key = 'dwellSeconds'
WHERE  we.event_name = 'channel-change'
AND    we.created_at >= now() - interval '30 days'
GROUP  BY 1
ORDER  BY 2 DESC;
```

## What to quote a sponsor

Once there's a month of data, the ticker pitch is three numbers:

1. **Monthly uniques** — from the dashboard.
2. **Average concurrent viewers, prime hours** — from the hour-of-day query.
3. **Average session length** — dashboard, or viewer-hours ÷ sessions.

The ticker is persistent and exclusive: one sponsor, on screen for the entire
session. Price it as a flat monthly, not a CPM — scarcity is what lets it beat
what a CPM calculation would justify, and a viewer who stays 20 minutes sees it
for 20 minutes.

## Known gaps

- **Ad blockers.** Expect 10–30% of traffic to be missed. Serving the tracker
  from a `stats.` subdomain helps; proxying it from the app's own origin under
  a neutral path helps more. Whatever the shortfall, it makes the reported
  numbers conservative, which is the safe direction when a buyer is relying
  on them.
- **Hidden tabs don't heartbeat.** Audio-only listening in a background tab is
  real viewing that goes uncounted. Deliberate — a background tab left open
  overnight would otherwise manufacture 480 viewer-minutes.
- **No server-side truth.** Everything here is client-reported and therefore
  spoofable. Fine for selling sponsorship; not sufficient for a
  revenue-share deal where a counterparty audits the numbers.
