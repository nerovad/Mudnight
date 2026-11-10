# Port of backend/src/controllers/filmController.ts (createFilm, listFilms,
# listFilmsForChannel) plus getMyFilms from profileController.ts, which is
# what routes/filmRoutes.ts wires to GET /api/films/mine.
module Api
  class FilmsController < ApplicationController
    before_action :authenticate_token!, only: :mine

    # POST /api/films  (no route-level auth; the handler checks the token)
    def create
      uid = auth_user_id_or_401
      return if performed? || Js.falsy?(uid)

      b = body
      title = b["title"]
      duration = b["duration"]
      # title?.trim(): undefined/null -> 400, non-string -> TypeError (500)
      unless title.nil?
        raise TypeError, "title.trim is not a function" unless title.is_a?(String)
      end
      if title.nil? || js_trim(title).empty?
        return render json: { error: "title is required" }, status: :bad_request
      end

      runtime_seconds = to_seconds(duration)

      row = Db.one(
        "
      insert into films (title, creator_user_id, runtime_seconds, created_at)
      values ($1, $2, $3, now())
      on conflict (title) do update set
        creator_user_id = coalesce(films.creator_user_id, excluded.creator_user_id),
        runtime_seconds = coalesce(excluded.runtime_seconds, films.runtime_seconds)
      returning id, title, creator_user_id, runtime_seconds, created_at
      ",
        [js_trim(title), uid, runtime_seconds]
      )

      render json: { id: row["id"], title: row["title"], duration: fmt_duration(row["runtime_seconds"]) }, status: :created
    end

    # GET /api/films
    def index
      rows = Db.query("select id, title, runtime_seconds from films order by id desc limit 500").rows
      render json: rows.map { |r| { id: r["id"], title: r["title"], duration: fmt_duration(r["runtime_seconds"]) } }
    end

    # GET /api/films/mine  (profileController.getMyFilms)
    def mine
      result = Db.query(
        "SELECT * FROM user_profile_film_links WHERE user_id = $1 ORDER BY position, id DESC",
        [current_user_id]
      )

      films = result.rows.map do |f|
        {
          "id" => f["id"].to_s,
          "title" => f["title"],
          "thumbnail" => f["thumbnail"],
          "duration" => f["duration"],
          "synopsis" => f["synopsis"],
          "url" => f["url"],
          "provider" => f["provider"]
        }
      end

      render json: films
    rescue StandardError => e
      Rails.logger.error("Get films error: #{e.message}")
      render json: { error: "Server error" }, status: :internal_server_error
    end

    # GET /api/channels/:channelId/films  and  GET /api/channels/:slug/films
    # Lineup for the channel's active session, or latest session if none.
    def channel_films
      channel_key = (Js.truthy?(params[:channelId]) ? params[:channelId] : params[:slug]).to_s

      cid = find_channel_id(channel_key)
      return render json: [] if Js.falsy?(cid)

      now_iso = Time.now.utc.iso8601(3)

      active = Db.query(
        "select id
         from sessions
        where channel_id = $1
          and starts_at <= $2
          and (ends_at is null or ends_at >= $2)
        order by starts_at desc
        limit 1",
        [cid, now_iso]
      )
      session_id = active.row_count.positive? ? active.rows[0]["id"] : nil

      if Js.falsy?(session_id)
        latest = Db.query(
          "select id
           from sessions
          where channel_id = $1
          order by starts_at desc
          limit 1",
          [cid]
        )
        session_id = latest.row_count.positive? ? latest.rows[0]["id"] : nil
      end

      return render json: [] if Js.falsy?(session_id)

      rows = Db.query(
        "select f.id, f.title, f.runtime_seconds, se.order_index
         from session_entries se
         join films f on f.id = se.film_id
        where se.session_id = $1
        order by se.order_index asc, f.id asc",
        [session_id]
      ).rows

      render json: rows.map { |r|
        {
          id: r["id"].to_s,
          title: r["title"],
          duration: fmt_duration(r["runtime_seconds"]),
          thumbnail: nil,
          synopsis: nil,
          order: r["order_index"]
        }
      }
    end

    private

    def auth_user_id_or_401
      h = request.headers["Authorization"].to_s
      token = h.start_with?("Bearer ") ? h[7..] : nil
      if Js.falsy?(token)
        render json: { error: "Access Denied" }, status: :unauthorized
        return nil
      end
      decoded = JsonWebToken.decode(token)
      decoded.is_a?(Hash) ? decoded["id"] : nil
    rescue JWT::DecodeError
      render json: { error: "Invalid Token" }, status: :unauthorized
      nil
    end

    def to_seconds(s)
      return nil if Js.falsy?(s)
      raise TypeError, "s.split is not a function" unless s.is_a?(String)

      parts = s.split(":", -1).map { |n| Js.number(n) }
      return nil if parts.any?(&:nil?)

      seconds =
        if parts.length == 3 then parts[0] * 3600 + parts[1] * 60 + parts[2]
        elsif parts.length == 2 then parts[0] * 60 + parts[1]
        else parts[0]
        end
      seconds.is_a?(Float) && seconds.finite? && seconds == seconds.floor ? seconds.to_i : seconds
    end

    def fmt_duration(sec)
      return nil if sec.nil?

      h = sec / 3600
      m = (sec % 3600) / 60
      s = sec % 60
      return format("%02d:%02d:%02d", h, m, s) if h.positive?

      format("%02d:%02d", m, s)
    end

    # Resolve a channel id by numeric id, or by slug/name/stream_key.
    def find_channel_id(key)
      if key.match?(/\A\d+\z/)
        r = Db.query("select id from channels where id = $1 limit 1", [js_number_param(key)])
        return r.row_count.positive? ? r.rows[0]["id"] : nil
      end
      rows = Db.query(
        "select id from channels
      where slug = $1 or name = $1 or stream_key = $1
      limit 1",
        [key]
      ).rows
      rows.any? ? rows[0]["id"] : nil
    end

    # Number(key) as node-pg would send it (e.g. "007" -> "7").
    def js_number_param(value)
      n = Js.number(value)
      n.is_a?(Float) && n.finite? && n == n.floor && n.abs < 1e21 ? n.to_i : n
    end

    def js_trim(value)
      value.gsub(/\A[[:space:]﻿]+|[[:space:]﻿]+\z/, "")
    end
  end
end
