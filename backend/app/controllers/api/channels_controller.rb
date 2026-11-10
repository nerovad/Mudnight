# Port of backend/src/controllers/channelController.ts (+ the middleware
# wiring from routes/channelRoutes.ts).
#
# Like the Express handlers, most actions re-check the bearer token with their
# own `authUserIdOr401` helper (messages "Access Denied" / "Invalid Token")
# after the route-level authenticateToken middleware has already run.
module Api
  class ChannelsController < ApplicationController
    before_action :authenticate_token!, only: %i[mine analytics create update destroy update_schedule]
    before_action -> { require_group!("super_admin", "network") }, only: :create

    CONTRIBUTION_POLICIES = %w[open invite closed].freeze

    # POST /api/channels
    def create
      uid = auth_user_id_or_401
      return if performed? || Js.falsy?(uid)

      b = body
      name = b["name"]
      slug = b["slug"]
      stream_url = b["stream_url"]
      display_name = b["display_name"]
      channel_number = b["channel_number"]
      event = b["event"]
      films = b["films"]
      widgets = b["widgets"]
      about_text = b["about_text"]
      first_live_at = b["first_live_at"]
      tags = b["tags"]
      thumbnail = b["thumbnail"]
      intermission = b["intermission"]
      schedule = b["schedule"]
      contribution_policy = b["contribution_policy"]

      if Js.falsy?(name) && Js.falsy?(slug)
        return render json: { error: "name (or slug) is required" }, status: :bad_request
      end

      if Js.truthy?(contribution_policy) && !CONTRIBUTION_POLICIES.include?(contribution_policy)
        return render json: { error: "contribution_policy must be 'open', 'invite', or 'closed'" }, status: :bad_request
      end

      slug = Js.truthy?(slug) ? Slugify.slugify(slug) : Slugify.slugify(name)

      conflict = false
      channel = nil
      session_row = nil
      film_rows = []
      tags_param = Js.truthy?(tags) && js_length(tags).to_i > 0 ? tags : nil
      widgets_param = Js.truthy?(widgets) ? JSON.generate(widgets) : nil

      Db.transaction do
        existing = Db.query(
          "select id, owner_id, name, stream_url, stream_key, ingest_app, playback_path, created_at
       from channels where slug = $1 limit 1",
          [slug]
        )

        if existing.row_count.positive?
          row = existing.rows[0]
          # Only owner can update this channel
          if row["owner_id"] != uid
            conflict = true
            raise ActiveRecord::Rollback
          end

          # Update name/stream_url only; preserve keys/paths.
          # (row has no display_name/channel_number columns, so those fall back
          # to NULL when omitted -- same as Express.)
          upd = Db.query(
            "update channels
         set name = $2, stream_url = $3, display_name = $4, channel_number = $5,
             widgets = COALESCE($6, widgets),
             about_text = COALESCE($7, about_text),
             first_live_at = COALESCE($8, first_live_at),
             tags = COALESCE($9, tags),
             contribution_policy = COALESCE($10, contribution_policy)
         where id = $1
         returning id, slug, name, stream_url, stream_key, ingest_app, playback_path, display_name, channel_number, widgets, about_text, first_live_at, tags, contribution_policy, created_at",
            [row["id"], nn(name, row["name"]), nn(stream_url, row["stream_url"]), nn(display_name, row["display_name"]),
             nn(channel_number, row["channel_number"]),
             widgets_param,
             about_text,
             first_live_at,
             tags_param,
             contribution_policy]
          )
          channel = upd.rows[0]
        else
          stream_key = generate_stream_key
          ingest_app = "live"
          playback_path = "/hls/#{stream_key}/index.m3u8"

          thumbnail_url = Js.truthy?(thumbnail) ? save_base64_image(thumbnail, slug, "thumbnails") : nil
          intermission_url = Js.truthy?(intermission) ? save_base64_image(intermission, slug, "intermissions") : nil

          ch = Db.query(
            "insert into channels
           (owner_id, slug, name, stream_url, stream_key, ingest_app, playback_path, display_name, channel_number, widgets, about_text, first_live_at, tags, thumbnail, intermission_url, contribution_policy, created_at)
         values ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15,$16, now())
         returning id, slug, name, stream_url, stream_key, ingest_app, playback_path, display_name, channel_number, widgets, about_text, first_live_at, tags, thumbnail, intermission_url, contribution_policy, created_at",
            [uid, slug, nn(name, slug), stream_url, stream_key, ingest_app, playback_path, display_name, channel_number,
             widgets_param,
             about_text,
             first_live_at,
             tags_param,
             thumbnail_url,
             intermission_url,
             nn(contribution_policy, "closed")]
          )
          channel = ch.rows[0]
        end

        # Schedule items for Now Playing / Up Next widget
        if schedule.is_a?(Array) && schedule.length.positive?
          schedule.each { |item| upsert_schedule_item(channel["id"], item) }
        end

        has_event_payload =
          Js.truthy?(event) &&
          (title = js_get(event, "title")).is_a?(String) && js_trim(title).length.positive? &&
          (starts = js_get(event, "starts_at")).is_a?(String) && js_trim(starts).length.positive?
        has_films = films.is_a?(Array) && films.length.positive?

        if has_event_payload && has_films
          event_kind = nn(event["kind"], "film_festival")
          voting_mode =
            if event_kind == "film_festival" then "ratings"
            elsif event_kind == "battle_royal" || event_kind == "tournament" then "battle"
            else "ratings"
            end
          require_login = true

          session_row = Db.one(
            "insert into sessions (channel_id, title, starts_at, ends_at, status, event_type, voting_mode, require_login, created_at)
         values ($1, $2, $3, $4, 'scheduled', $5, $6, $7, now())
         returning id, channel_id, title, starts_at, ends_at, status, event_type, voting_mode, require_login",
            [channel["id"], event["title"], event["starts_at"], event["ends_at"], event_kind, voting_mode, require_login]
          )

          film_rows = insert_lineup(films, session_row["id"], uid, "lower")

          # Tournament bracket handling
          if event["kind"] == "tournament" && Js.truthy?(event["tournament_bracket"])
            bracket = event["tournament_bracket"]
            Rails.logger.info("Creating tournament bracket for session: #{session_row['id']}")

            Db.query("UPDATE sessions SET tournament_bracket = $1 WHERE id = $2",
                     [JSON.generate(bracket), session_row["id"]])

            rounds = js_get(bracket, "rounds")
            if Js.truthy?(rounds) && rounds.is_a?(Array)
              first_round = rounds.find { |r| js_get(r, "roundNumber") == 1 }
              if Js.truthy?(first_round) && Js.truthy?(js_get(first_round, "matchups"))
                matchups = js_iterable(first_round["matchups"])
                matchups.each do |matchup|
                  film1_db_id = nil
                  film2_db_id = nil

                  film1 = js_get(matchup, "film1")
                  if Js.truthy?(film1)
                    wanted = js_trim(js_lower(js_get(film1, "title")))
                    film1_db_id = film_rows.find { |fr| wanted == js_trim(fr["title"].downcase) }&.dig("id")
                  end

                  film2 = js_get(matchup, "film2")
                  if Js.truthy?(film2)
                    wanted = js_trim(js_lower(js_get(film2, "title")))
                    film2_db_id = film_rows.find { |fr| wanted == js_trim(fr["title"].downcase) }&.dig("id")
                  end

                  Db.query(
                    "INSERT INTO tournament_matchups (session_id, matchup_id, round_number, position, film1_id, film2_id)
                VALUES ($1, $2, $3, $4, $5, $6)",
                    [session_row["id"], js_get(matchup, "id"), first_round["roundNumber"], js_get(matchup, "position"),
                     Js.truthy?(film1_db_id) ? film1_db_id.to_s : nil,
                     Js.truthy?(film2_db_id) ? film2_db_id.to_s : nil]
                  )
                end
                Rails.logger.info("Created #{matchups.length} tournament matchups")
              end
            end
          end
        end
      end

      if conflict
        return render json: { error: "Channel slug is already in use by another user." }, status: :conflict
      end

      render json: channel.merge("session" => session_row, "films" => film_rows), status: :created
    end

    # GET /api/channels -> must return an ARRAY
    def index
      rows = Db.query(
        "select id, slug, name, stream_url, stream_key, ingest_app, playback_path, channel_number, display_name, tags, intermission_url, created_at
       from channels order by created_at desc"
      ).rows
      render json: rows
    end

    # GET /api/channels/:slug
    def show
      slug = params[:slug].to_s
      rows = Db.query(
        "select c.id, c.slug, c.name, c.stream_url, c.stream_key, c.ingest_app, c.playback_path,
              c.display_name, c.channel_number, c.widgets, c.about_text, c.first_live_at, c.thumbnail, c.intermission_url, c.created_at,
              c.owner_id, c.contribution_policy, c.playout_mode,
              u.username as owner_name
       from channels c
       left join users u on c.owner_id = u.id
       where c.slug = $1 limit 1",
        [slug]
      ).rows
      return render json: { error: "Channel not found" }, status: :not_found if rows.empty?

      channel = rows[0]

      latest_session = Db.one(
        "select id, title, starts_at, ends_at, status, event_type
       from sessions where channel_id = $1
       order by starts_at desc limit 1",
        [channel["id"]]
      )

      all_sessions = Db.query(
        "select id, title, starts_at, ends_at, status, event_type, created_at
       from sessions where channel_id = $1
       order by starts_at desc",
        [channel["id"]]
      )

      render json: channel.merge(
        "latestSession" => latest_session,
        "event_type" => latest_session ? latest_session["event_type"] : nil,
        "sessions" => all_sessions.rows
      )
    end

    # PATCH /api/channels/:id
    def update
      uid = auth_user_id_or_401
      return if performed? || Js.falsy?(uid)

      channel_id = params[:id]
      b = body
      event = b["event"]
      films = b["films"]
      widgets = b["widgets"]
      contribution_policy = b["contribution_policy"]

      if Js.truthy?(contribution_policy) && !CONTRIBUTION_POLICIES.include?(contribution_policy)
        return render json: { error: "contribution_policy must be 'open', 'invite', or 'closed'" }, status: :bad_request
      end

      forbidden = false
      updated = nil
      session_row = nil

      Db.transaction do
        ownership = Db.query("SELECT id, slug FROM channels WHERE id = $1 AND owner_id = $2", [channel_id, uid])
        if ownership.row_count.zero?
          forbidden = true
          raise ActiveRecord::Rollback
        end

        channel_slug = ownership.rows[0]["slug"]

        thumbnail_url = Js.truthy?(b["thumbnail"]) ? save_base64_image(b["thumbnail"], channel_slug, "thumbnails") : nil
        intermission_url = Js.truthy?(b["intermission"]) ? save_base64_image(b["intermission"], channel_slug, "intermissions") : nil

        updated = Db.one(
          "UPDATE channels
       SET display_name = COALESCE($1, display_name),
           description = COALESCE($2, description),
           widgets = COALESCE($3, widgets),
           about_text = COALESCE($4, about_text),
           first_live_at = COALESCE($5, first_live_at),
           thumbnail = COALESCE($7, thumbnail),
           intermission_url = COALESCE($8, intermission_url),
           contribution_policy = COALESCE($9, contribution_policy)
       WHERE id = $6
       RETURNING *",
          [b["display_name"], b["description"], Js.truthy?(widgets) ? JSON.generate(widgets) : nil, b["about_text"],
           b["first_live_at"], channel_id, thumbnail_url, intermission_url, contribution_policy]
        )

        if Js.truthy?(event) && Js.truthy?(films) && js_length(films).to_i.positive?
          session_row = Db.one(
            "INSERT INTO sessions (channel_id, title, starts_at, ends_at, status, created_at)
         VALUES ($1, $2, $3, $4, 'scheduled', now())
         RETURNING id, channel_id, title, starts_at, ends_at, status",
            [channel_id, js_get(event, "title"), js_get(event, "starts_at"), js_get(event, "ends_at")]
          )

          insert_lineup(js_iterable(films), session_row["id"], uid, "LOWER")
        end
      end

      return render json: { error: "Not authorized to edit this channel" }, status: :forbidden if forbidden

      render json: updated.merge("session" => session_row)
    end

    # DELETE /api/channels/:id
    def destroy
      uid = auth_user_id_or_401
      return if performed? || Js.falsy?(uid)

      channel_id = params[:id]
      forbidden = false

      Db.transaction do
        ownership = Db.query("SELECT id FROM channels WHERE id = $1 AND owner_id = $2", [channel_id, uid])
        if ownership.row_count.zero?
          forbidden = true
          raise ActiveRecord::Rollback
        end

        Db.query(
          "DELETE FROM session_entries WHERE session_id IN (
         SELECT id FROM sessions WHERE channel_id = $1
       )",
          [channel_id]
        )
        Db.query("DELETE FROM sessions WHERE channel_id = $1", [channel_id])
        Db.query("DELETE FROM channels WHERE id = $1", [channel_id])
      end

      return render json: { error: "Not authorized to delete this channel" }, status: :forbidden if forbidden

      render json: { success: true, message: "Channel deleted successfully" }
    end

    # GET /api/channels/mine
    def mine
      uid = auth_user_id_or_401
      return if performed? || Js.falsy?(uid)

      r = Db.query(
        "SELECT
       c.id,
       c.slug,
       c.name,
       c.display_name,
       c.channel_number,
       c.stream_url,
       null::text as description,
       false as \"isLive\",
       c.thumbnail,
       s.id as session_id,
       s.event_type
     FROM channels c
     LEFT JOIN sessions s ON s.channel_id = c.id AND s.is_active = true
     WHERE c.owner_id = $1
     ORDER BY c.channel_number ASC",
        [uid]
      )
      render json: r.rows
    end

    # GET /api/channels/:slug/schedule
    def schedule
      slug = params[:slug]
      ch = Db.query("SELECT id FROM channels WHERE slug = $1", [slug])
      return render json: { error: "Channel not found" }, status: :not_found if ch.rows.empty?

      channel_id = ch.rows[0]["id"]
      now = Time.now

      # Now Playing from the as-run log (ground truth); see channelController.ts.
      as_run = Db.query(
        "SELECT a.id, a.segment_id, a.source, a.title, a.started_at, a.duration_ms, a.is_ingest,
              COALESCE(sm.title, bm.title) AS current_title
         FROM channel_asrun a
         LEFT JOIN channel_segments s ON s.id = a.segment_id
         LEFT JOIN channel_media sm ON sm.id = s.media_id
         LEFT JOIN channel_media bm
                ON bm.channel_id = a.channel_id
               AND bm.storage_path = regexp_replace(a.source, '^.*/', '')
        WHERE a.channel_id = $1
        ORDER BY a.started_at DESC
        LIMIT 1",
        [channel_id]
      )

      as_run_now_playing = nil
      if as_run.rows.any?
        r = as_run.rows[0]
        display_title = Js.truthy?(r["current_title"]) ? r["current_title"] : r["title"]
        started = js_ms(r["started_at"])
        dur = r["duration_ms"]
        # duration_ms is BIGINT, which node-pg returns as a string, so Express
        # computed `started + durMs + 60000` as string concatenation and the
        # comparison against that huge number is effectively always true when
        # a duration is present. Reproduced as-is.
        threshold = dur.nil? ? started + 3_600_000 + 60_000 : Js.number("#{started}#{dur}60000")
        if threshold && js_ms(now) < threshold
          as_run_now_playing = {
            "id" => nn(r["segment_id"], r["id"]),
            "film_id" => nil,
            "film_title" => display_title,
            "title" => display_title,
            "scheduled_at" => r["started_at"],
            "duration_seconds" => dur.nil? ? nil : js_round(Js.number(dur) / 1000.0),
            "status" => "airing",
            "source" => r["source"],
            "is_ingest" => r["is_ingest"],
            "from_asrun" => true
          }
        end
      end

      all_rows = Db.query(
        "SELECT cs.*,
              COALESCE(f.title, cs.title) as display_title,
              f.id as film_id
       FROM channel_schedule cs
       LEFT JOIN films f ON cs.film_id = f.id
       WHERE cs.channel_id = $1
       ORDER BY cs.scheduled_at ASC",
        [channel_id]
      ).rows
      all_rows.each { |row| row["recurrence_end_date"] = pg_date(row["recurrence_end_date"]) if row.key?("recurrence_end_date") }

      if all_rows.empty?
        return render json: { now_playing: as_run_now_playing, up_next: [], schedule: [] }
      end

      expanded = expand_recurring_items(all_rows, 7)

      now_playing = nil
      up_next = []
      expanded.each do |item|
        scheduled_time = js_date(item["scheduled_at"])
        end_time = Js.truthy?(item["duration_seconds"]) ? scheduled_time + item["duration_seconds"] : scheduled_time + 3600
        if scheduled_time <= now && now < end_time
          now_playing = item
        elsif scheduled_time > now
          up_next << item
        end
      end

      if now_playing.nil? && expanded.any?
        past = expanded.select { |item| js_date(item["scheduled_at"]) <= now }
        now_playing = past.last if past.any?
      end

      now_playing = up_next.shift if now_playing.nil? && up_next.any?

      render json: {
        now_playing: as_run_now_playing || now_playing,
        up_next: up_next.first(5),
        schedule: all_rows
      }
    rescue StandardError => e
      Rails.logger.error("Error fetching schedule: #{e.message}")
      render json: { error: "Failed to fetch schedule" }, status: :internal_server_error
    end

    # POST /api/channels/:slug/schedule
    def update_schedule
      slug = params[:slug]
      uid = auth_user_id_or_401
      return if performed?

      schedule = body["schedule"]
      unless Js.truthy?(schedule) && schedule.is_a?(Array)
        return render json: { error: "Schedule must be an array" }, status: :bad_request
      end

      outcome = nil
      inserted = 0
      begin
        Db.transaction do
          ch = Db.query("SELECT id, owner_id FROM channels WHERE slug = $1", [slug])
          if ch.rows.empty?
            outcome = :not_found
            raise ActiveRecord::Rollback
          end
          channel = ch.rows[0]
          if channel["owner_id"] != uid
            outcome = :forbidden
            raise ActiveRecord::Rollback
          end

          schedule.each do |item|
            inserted += 1 if upsert_schedule_item(channel["id"], item, returning: true)
          end
        end
      rescue StandardError => e
        Rails.logger.error("Error updating schedule: #{e.message}")
        return render json: { error: "Failed to update schedule", details: js_error_message(e) }, status: :internal_server_error
      end

      return render json: { error: "Channel not found" }, status: :not_found if outcome == :not_found
      return render json: { error: "Not authorized" }, status: :forbidden if outcome == :forbidden

      render json: { success: true, count: inserted }
    end

    # GET /api/channels/:channelId/analytics
    def analytics
      uid = auth_user_id_or_401
      return if performed? || Js.falsy?(uid)

      channel_id = params[:channelId]
      begin
        channel = Db.one(
          "SELECT id, display_name, name, channel_number, created_at, first_live_at, owner_id
       FROM channels WHERE id = $1",
          [channel_id]
        )
        return render json: { error: "Channel not found" }, status: :not_found unless channel
        return render json: { error: "Not authorized" }, status: :forbidden if channel["owner_id"] != uid

        analytics = ChannelAnalytics.build(Js.parse_int(channel_id))
        render json: { "channel" => channel }.merge(analytics)
      rescue StandardError => e
        Rails.logger.error("Channel analytics error: #{e.message}")
        render json: { error: "Server error" }, status: :internal_server_error
      end
    end

    private

    # authUserIdOr401: renders 401 and returns nil when the Bearer token is
    # missing/invalid. A valid token without an `id` claim returns nil without
    # rendering (Express then returned without responding at all).
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

    def generate_stream_key
      SecureRandom.hex(16)
    end

    # parseDurationToSeconds
    def parse_duration_to_seconds(s)
      return nil if Js.falsy?(s)
      raise TypeError, "s.split is not a function" unless s.is_a?(String)

      parts = s.split(":", -1).map { |p| Js.number(p) }
      return nil if parts.any?(&:nil?)

      seconds =
        case parts.length
        when 3 then parts[0] * 3600 + parts[1] * 60 + parts[2]
        when 2 then parts[0] * 60 + parts[1]
        when 1 then parts[0]
        end
      js_int(seconds)
    end

    # saveBase64Image: writes a data: URL into uploads/<subfolder>, returns the
    # public /uploads/... path or nil.
    def save_base64_image(base64_data, channel_slug, subfolder = "thumbnails")
      return nil if Js.falsy?(base64_data)
      return nil unless base64_data.is_a?(String)

      matches = base64_data.match(%r{\Adata:(?:image|video)/(\w+);base64,([^\n\r  ]+)\z})
      return nil unless matches

      extension = matches[1]
      buffer = Base64.decode64(matches[2])

      uploads_dir = Rails.root.join("uploads", subfolder)
      FileUtils.mkdir_p(uploads_dir)

      filename = "#{channel_slug}-#{(Time.now.to_r * 1000).to_i}.#{extension}"
      File.binwrite(uploads_dir.join(filename), buffer)

      "/uploads/#{subfolder}/#{filename}"
    rescue StandardError => e
      Rails.logger.error("Failed to save #{subfolder} image: #{e.message}")
      nil
    end

    # Shared schedule upsert used by createChannel and updateChannelSchedule.
    # Returns false when the item is skipped.
    def upsert_schedule_item(channel_id, item, returning: false)
      scheduled_at = js_get(item, "scheduled_at")
      return false if Js.falsy?(scheduled_at) || (Js.falsy?(js_get(item, "title")) && Js.falsy?(js_get(item, "film_id")))

      title = item["title"]
      if Js.truthy?(item["film_id"]) && Js.falsy?(title)
        film = Db.query("SELECT title FROM films WHERE id = $1", [item["film_id"]])
        title = film.rows[0]["title"] if film.rows.any?
      end

      sql = "INSERT INTO channel_schedule
           (channel_id, film_id, title, scheduled_at, duration_seconds, status, recurrence_type, recurrence_days, recurrence_end_date, air_time)
         VALUES ($1, $2, $3, $4, $5, 'scheduled', $6, $7, $8, $9)
         ON CONFLICT (channel_id, scheduled_at)
         DO UPDATE SET
           film_id = EXCLUDED.film_id,
           title = EXCLUDED.title,
           duration_seconds = EXCLUDED.duration_seconds,
           recurrence_type = EXCLUDED.recurrence_type,
           recurrence_days = EXCLUDED.recurrence_days,
           recurrence_end_date = EXCLUDED.recurrence_end_date,
           air_time = EXCLUDED.air_time"
      sql += "\n         RETURNING id" if returning

      Db.query(sql, [
        channel_id,
        js_or(item["film_id"], nil),
        js_or(title, nil),
        scheduled_at,
        js_or(item["duration_seconds"], nil),
        js_or(item["recurrence_type"], "once"),
        js_or(item["recurrence_days"], nil),
        js_or(item["recurrence_end_date"], nil),
        js_or(item["air_time"], nil)
      ])
      true
    end

    # Films -> session_entries loop shared by create/update. Returns filmRows.
    def insert_lineup(films, session_id, uid, lower_kw)
      film_rows = []
      films.each_with_index do |f, i|
        title = f.nil? ? nil : js_get(f, "title")
        next if Js.falsy?(title) || js_trim(title).empty?

        trimmed = js_trim(title)
        runtime_seconds = parse_duration_to_seconds(f["duration"])

        found = if lower_kw == "lower"
          Db.query("select id, title from films where lower(title) = lower($1) limit 1", [trimmed])
        else
          Db.query("SELECT id, title FROM films WHERE lower(title) = lower($1) LIMIT 1", [trimmed])
        end

        film_id =
          if found.row_count.positive?
            found.rows[0]["id"]
          else
            Db.one(
              "insert into films (title, creator_user_id, runtime_seconds, created_at)
             values ($1, $2, $3, now())
             returning id, title",
              [trimmed, uid, runtime_seconds]
            )["id"]
          end

        film_rows << { "id" => film_id, "title" => trimmed }

        Db.query("insert into session_entries (session_id, film_id, order_index)
           values ($1, $2, $3)", [session_id, film_id, i])
      end
      film_rows
    end

    # expandRecurringItems: expand recurring schedule rows into individual
    # occurrences for the next `days_ahead` days, in server-local time (like
    # the JS Date setHours/getDay calls).
    def expand_recurring_items(items, days_ahead = 7)
      now = Time.now
      end_date = now + days_ahead * 24 * 60 * 60
      expanded = []

      items.each do |item|
        recurrence_type = js_or(item["recurrence_type"], "once")
        if recurrence_type == "once"
          expanded << item
          next
        end

        start_date = js_date(item["scheduled_at"])
        air_time = js_or(item["air_time"], "00:00")
        hours, minutes = air_time.to_s.split(":", -1).map { |p| Js.number(p) }
        recurrence_end = Js.truthy?(item["recurrence_end_date"]) ? js_date(item["recurrence_end_date"]) : nil

        days_of_week =
          case recurrence_type
          when "daily" then [0, 1, 2, 3, 4, 5, 6]
          when "weekdays" then [1, 2, 3, 4, 5]
          when "weekends" then [0, 6]
          when "weekly" then js_or(item["recurrence_days"], [])
          else []
          end

        start_ms = [js_ms(start_date), js_ms(now) - 24 * 60 * 60 * 1000].max
        day = Time.at(Rational(start_ms, 1000)).localtime.to_date
        current = Time.local(day.year, day.month, day.day)

        while current <= end_date
          if days_of_week.include?(current.wday) &&
             current >= start_date && (recurrence_end.nil? || current <= recurrence_end)
            # JS: setHours(NaN) -> Invalid Date -> toISOString throws RangeError
            raise RangeError, "Invalid time value" if hours.nil? || minutes.nil?

            occurrence = local_time_at(day, hours, minutes)
            expanded << item.merge(
              "scheduled_at" => occurrence.utc.iso8601(3),
              "is_recurring_instance" => true,
              "original_id" => item["id"]
            )
          end

          day = day.next_day
          current = Time.local(day.year, day.month, day.day)
        end
      end

      # Stable sort by scheduled_at (Array.prototype.sort is stable).
      expanded.each_with_index.sort_by { |item, i| [js_ms(js_date(item["scheduled_at"])), i] }.map(&:first)
    end

    def local_time_at(day, hours, minutes)
      h = hours.to_i
      m = minutes.to_i
      if h.between?(0, 23) && m.between?(0, 59)
        Time.local(day.year, day.month, day.day, h, m, 0)
      else
        Time.local(day.year, day.month, day.day) + h * 3600 + m * 60
      end
    end

    # --- JS semantics helpers ---

    # a ?? b
    def nn(a, b) = a.nil? ? b : a

    # a || b
    def js_or(a, b) = Js.truthy?(a) ? a : b

    # obj.key: TypeError on null/undefined, undefined on non-objects.
    def js_get(obj, key)
      raise TypeError, "Cannot read properties of #{obj.nil? ? 'null' : 'undefined'} (reading '#{key}')" if obj.nil?

      obj.is_a?(Hash) ? obj[key] : nil
    end

    def js_trim(value)
      raise TypeError, "value.trim is not a function" unless value.is_a?(String)

      value.gsub(/\A[[:space:]﻿]+|[[:space:]﻿]+\z/, "")
    end

    def js_lower(value)
      raise TypeError, "value.toLowerCase is not a function" unless value.is_a?(String)

      value.downcase
    end

    def js_length(value)
      value.is_a?(String) || value.is_a?(Array) ? value.length : nil
    end

    # for...of: arrays iterate elements, strings iterate characters.
    def js_iterable(value)
      return value if value.is_a?(Array)
      return value.chars if value.is_a?(String)

      raise TypeError, "value is not iterable"
    end

    def js_int(value)
      value.is_a?(Float) && value.finite? && value == value.floor ? value.to_i : value
    end

    def js_round(value) = (value + 0.5).floor

    def js_ms(time) = (time.to_r * 1000).floor

    # new Date(value)
    def js_date(value)
      case value
      when Time then value
      when Date then Time.local(value.year, value.month, value.day)
      else Time.iso8601(value.to_s)
      end
    rescue ArgumentError
      Time.parse(value.to_s)
    end

    # node-postgres parses DATE columns into a JS Date at local midnight
    # (serialised as an ISO timestamp); lib/db.rb leaves them as "YYYY-MM-DD".
    def pg_date(value)
      return value unless value.is_a?(String) || value.is_a?(Date)

      d = value.is_a?(Date) ? value : Date.iso8601(value)
      Time.local(d.year, d.month, d.day).utc
    rescue ArgumentError
      value
    end

    def js_error_message(error)
      if error.is_a?(Db::Error) && error.pg_error.respond_to?(:result) && error.pg_error.result
        error.pg_error.result.error_field(PG::Result::PG_DIAG_MESSAGE_PRIMARY) || error.message
      else
        error.message
      end
    end
  end
end
