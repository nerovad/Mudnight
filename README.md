# Cinezoo

A full-stack live streaming platform for hosting interactive film festivals, tournaments, and community events with real-time voting, live chat, and multi-channel broadcasting.

**Live at [cinezoo.tv](https://cinezoo.tv)**

## Tech Stack

**Frontend:** React 18, TypeScript, Vite, Zustand, SASS, Bootstrap, HLS.js

**Backend:** Ruby on Rails 8.1 (API mode), PostgreSQL, ActionCable, JWT

**Mobile:** React Native, Expo

**Infrastructure:** nginx-rtmp, Puma under PM2, HLS streaming

**Architecture:** Rails API in `backend/`; npm workspaces monorepo for the React clients, with a shared package for types, API clients, stores, and the realtime (ActionCable) client across frontend and mobile

## Features

- **Multi-Channel Live Streaming** -- RTMP ingest via nginx-rtmp with HLS playback, stream key authentication, custom intermission screens, and channel thumbnails
- **Three Voting Modes** -- Film festival ratings (0-5 scale with weighted leaderboards), head-to-head tournament brackets, and battle royale format
- **Real-Time Chat** -- ActionCable-powered live chat per channel with message history and automatic cleanup
- **Session Management** -- Schedule and manage events with ordered film lineups, status lifecycle (scheduled/live/closed/archived), and recurrence support
- **Admin Dashboard** -- Channel creation, stream key management, festival controls, lineup editing, user role management, and media uploads
- **User System** -- JWT auth with role-based access (super_admin, network, general_user), profiles with social links, company affiliations, and awards
- **Direct Messaging** -- Private user-to-user messaging with automatic expiration
- **Configurable Widgets** -- Per-channel widget system (voting ballots, leaderboards, tournament brackets) stored as JSONB

## Database Design

PostgreSQL. The schema lives in `backend/db/structure.sql` (SQL format, since it uses partitions and triggers); new changes are Rails migrations. The pre-Rails SQL migrations are kept in `legacy/db/`. Voting tables use hash partitioning (8 partitions each for ratings and match_votes) to handle high-concurrency scenarios during live events.

## Project Structure

```
/Cinezoo
├── backend/        Rails 8.1 API (app/controllers/api, app/channels, app/services)
├── frontend/       React (Vite) client
├── mobile/         React Native (Expo) app
├── shared/         Shared types, API clients, stores, utilities, realtime client
├── legacy/db/      SQL migrations from the Express era (history only)
├── deploy.sh       Production deployment script
├── ecosystem.config.js   PM2 process config (runs Puma)
└── .env            Environment variables (not committed), read by Rails and Vite tooling
```

---

## Starting the App

Requirements: Ruby 4.0, Node 25, PostgreSQL.

```sh
npm install                      # frontend, mobile, shared
(cd backend && bundle install)
(cd backend && bin/rails db:prepare)   # new DB: loads db/structure.sql; existing DB: runs pending migrations
```

### Running in development

Run the backend and frontend in two terminals.

**Terminal 1: backend (Rails, http://localhost:4000)**

```sh
cd backend
bin/rails server
```

**Terminal 2: frontend (Vite, http://localhost:5173)**

```sh
cd frontend
npm run dev
```

Open http://localhost:5173. Vite forwards `/api`, `/uploads` and `/cable` to Rails on port 4000, so keep the backend running.

If Rails says `Address already in use ... port 4000`, another server is still running. Find it with `ss -ltnp | grep 4000` and stop it.

Prod: `./deploy.sh`. PM2 runs Puma (`ecosystem.config.js`) and is configured to auto-start on reboot via systemd.
Production needs `backend/config/master.key` (or `SECRET_KEY_BASE`) on the server.

### Notes on the Rails port

- Handlers run the same hand-written SQL as the Express version through `Db.query` (`backend/lib/db.rb`), which decodes rows the way node-postgres did, so API responses are byte-compatible with the clients.
- Live chat runs over ActionCable (`backend/app/channels/chat_channel.rb`). Clients use `@cinezoo/shared/realtime`, a socket.io-shaped wrapper, so components kept their `on`/`emit` code.
- Viewer counts and on-demand playout state are held in process memory, so run a single Puma process (threads are fine).
- The existing database already has a `schema_migrations` table owned by the old migration runner, so Rails tracks its own migrations in `rails_schema_migrations`.
