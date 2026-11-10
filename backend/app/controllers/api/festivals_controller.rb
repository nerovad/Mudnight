# Port of backend/src/controllers/festivalController.ts (session controls).
# No auth on these routes in Express either.
module Api
  class FestivalsController < ApplicationController
    # POST /api/festivals
    def create
      b = body
      channel_slug = b["channelSlug"]
      title = b["title"]

      if Js.falsy?(channel_slug) || Js.falsy?(title)
        return render json: { error: "channelSlug and title are required" }, status: :bad_request
      end

      ch = Db.query("SELECT id FROM channels WHERE slug = $1 LIMIT 1", [channel_slug])
      return render json: { error: "Channel not found" }, status: :not_found if ch.row_count.zero?

      channel_id = ch.rows[0]["id"]
      row = Db.one(
        "INSERT INTO sessions (channel_id, title, starts_at, ends_at, status, timezone)
       VALUES ($1, $2, COALESCE($3, now()), $4, COALESCE($5, 'scheduled'), $6)
       RETURNING id, channel_id, title, starts_at, ends_at, status, timezone, created_at",
        [channel_id, title, b["starts_at"], b["ends_at"], b["status"], b["timezone"]]
      )

      render json: row, status: :created
    end

    # POST /api/festivals/:sessionId/start
    def start
      rows = Db.query(
        "UPDATE sessions
          SET status = 'live',
              starts_at = COALESCE(starts_at, now())
        WHERE id = $1
      RETURNING id, channel_id, title, starts_at, ends_at, status",
        [js_number_param(params[:sessionId])]
      ).rows
      return render json: { error: "Session not found" }, status: :not_found if rows.empty?

      render json: rows[0]
    end

    # POST /api/festivals/:sessionId/close
    def close
      rows = Db.query(
        "UPDATE sessions
          SET status = 'closed',
              ends_at = COALESCE(ends_at, now())
        WHERE id = $1
      RETURNING id, channel_id, title, starts_at, ends_at, status",
        [js_number_param(params[:sessionId])]
      ).rows
      return render json: { error: "Session not found" }, status: :not_found if rows.empty?

      render json: rows[0]
    end

    # POST /api/festivals/:sessionId/entries
    def add_entry
      session_id = js_number_param(params[:sessionId])
      b = body
      film_id = b["filmId"]
      film_title = b["filmTitle"]

      if Js.falsy?(film_id) && Js.falsy?(film_title)
        return render json: { error: "filmId or filmTitle is required" }, status: :bad_request
      end

      id_to_use = film_id

      if Js.falsy?(id_to_use)
        # filmTitle!.trim(): TypeError (-> 500) when missing or not a string
        raise TypeError, "filmTitle.trim is not a function" unless film_title.is_a?(String)

        f = Db.one(
          "INSERT INTO films (title)
         VALUES ($1)
         ON CONFLICT (title) DO UPDATE SET title = EXCLUDED.title
         RETURNING id, title",
          [film_title.gsub(/\A[[:space:]﻿]+|[[:space:]﻿]+\z/, "")]
        )
        id_to_use = f["id"]
      end

      row = Db.one(
        "INSERT INTO session_entries (session_id, film_id, order_index)
       VALUES ($1, $2, COALESCE($3, (
         SELECT COALESCE(MAX(order_index), 0) + 1 FROM session_entries WHERE session_id = $1
       )))
       RETURNING id, session_id, film_id, order_index",
        [session_id, id_to_use, b["order_index"]]
      )

      render json: row, status: :created
    end

    # GET /api/festivals/:sessionId/lineup
    def lineup
      rows = Db.query(
        "SELECT se.id AS entry_id,
              se.order_index,
              f.id  AS film_id,
              f.title
         FROM session_entries se
         JOIN films f ON f.id = se.film_id
        WHERE se.session_id = $1
        ORDER BY se.order_index ASC, se.id ASC",
        [js_number_param(params[:sessionId])]
      ).rows
      render json: rows
    end

    private

    # Number(param) as node-pg sends it: NaN -> "NaN" (a Postgres error -> 500),
    # integral floats like 1e3 -> 1000.
    def js_number_param(value)
      n = Js.number(value)
      return "NaN" if n.nil?

      n.is_a?(Float) && n.finite? && n == n.floor && n.abs < 1e21 ? n.to_i : n
    end
  end
end
