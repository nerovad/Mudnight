# Port of controllers/contributionController.ts (routes/contributionRoutes.ts and
# the contribution/contributor routes of routes/channelRoutes.ts).
#
# Open Source TV: viewers pitch films to a channel ("pull requests"), the
# channel owner accepts or declines. Accepted pitches with a proposed slot are
# materialized into channel_schedule with an attribution pointer.
#
# Errors fall through to ApplicationController's 500 handler (next(err)).
module Api
  class ContributionsController < ApplicationController
    before_action :authenticate_token!, except: :contributors

    # Spam pressure: a user may only have this many open pitches per channel.
    MAX_PENDING_PER_USER_PER_CHANNEL = 3

    # POST /api/channels/:slug/contributions
    def create
      uid = auth_user_id_or_401
      return unless Js.truthy?(uid)

      film_id = body["film_id"]
      proposed_slot = body["proposed_slot"]
      pitch_text = body["pitch_text"]
      rights_confirmed = body["rights_confirmed"]

      return render(json: { error: "film_id is required" }, status: 400) if Js.falsy?(film_id)

      if rights_confirmed != true
        return render(json: { error: "You must confirm you hold the rights to this film and grant the channel permission to air it." }, status: 400)
      end

      if Js.truthy?(proposed_slot) && Js.falsy?(prop(proposed_slot, "scheduled_at"))
        return render(json: { error: "proposed_slot requires scheduled_at" }, status: 400)
      end

      channel = find_channel_by_slug(params[:slug].to_s)
      return render(json: { error: "Channel not found" }, status: 404) unless channel

      film = Db.query("SELECT id FROM films WHERE id = $1 LIMIT 1", [film_id])
      return render(json: { error: "Film not found" }, status: 404) if film.row_count.zero?

      is_owner = channel["owner_id"] == uid
      membership = Db.one(
        "SELECT role FROM channel_contributors WHERE channel_id = $1 AND user_id = $2 LIMIT 1",
        [channel["id"], uid]
      )
      role = membership && membership["role"]

      unless is_owner
        if channel["contribution_policy"] == "closed"
          return render(json: { error: "This channel is not accepting contributions." }, status: 403)
        end
        if channel["contribution_policy"] == "invite" && Js.falsy?(role)
          return render(json: { error: "This channel accepts contributions by invite only." }, status: 403)
        end

        pending = Db.one(
          "SELECT COUNT(*)::int AS n FROM channel_contributions
         WHERE channel_id = $1 AND contributor_id = $2 AND status = 'pending'",
          [channel["id"], uid]
        )
        if pending["n"] >= MAX_PENDING_PER_USER_PER_CHANNEL
          return render(json: { error: "You already have #{MAX_PENDING_PER_USER_PER_CHANNEL} pending pitches on this channel. Wait for a review before pitching more." }, status: 429)
        end
      end

      # Owner and trusted contributors skip review ("commit access").
      auto_accept = is_owner || role == "trusted"

      contribution, schedule_item_id = Db.transaction do
        row = Db.one(
          "INSERT INTO channel_contributions
         (channel_id, contributor_id, film_id, proposed_slot, pitch_text, rights_confirmed, status, reviewed_at)
       VALUES ($1, $2, $3, $4, $5, true, $6, $7)
       RETURNING *",
          [
            channel["id"],
            uid,
            film_id,
            Js.truthy?(proposed_slot) ? JSON.generate(proposed_slot) : nil,
            trim_or_null(pitch_text),
            auto_accept ? "accepted" : "pending",
            auto_accept ? Time.now.utc.iso8601(3) : nil
          ]
        )
        [row, auto_accept ? materialize_contribution(row) : nil]
      end

      render json: contribution.merge("auto_accepted" => auto_accept, "schedule_item_id" => schedule_item_id), status: 201
    end

    # GET /api/channels/:slug/contributions?status=pending
    # Owner sees every pitch; everyone else sees only their own.
    def channel_index
      uid = auth_user_id_or_401
      return unless Js.truthy?(uid)

      channel = find_channel_by_slug(params[:slug].to_s)
      return render(json: { error: "Channel not found" }, status: 404) unless channel

      is_owner = channel["owner_id"] == uid
      status = request.query_parameters["status"]
      status = nil unless status.is_a?(String)

      query_params = [channel["id"]]
      where = "cc.channel_id = $1"
      unless is_owner
        query_params << uid
        where += " AND cc.contributor_id = $#{query_params.length}"
      end
      if Js.truthy?(status)
        query_params << status
        where += " AND cc.status = $#{query_params.length}"
      end

      rows = Db.query(
        "SELECT cc.*,
              u.username AS contributor_name,
              f.title AS film_title,
              f.runtime_seconds AS film_runtime_seconds
       FROM channel_contributions cc
       JOIN users u ON u.id = cc.contributor_id
       JOIN films f ON f.id = cc.film_id
       WHERE #{where}
       ORDER BY (cc.status = 'pending') DESC, cc.created_at DESC",
        query_params
      ).rows

      response = { is_owner: is_owner, contributions: rows }
      # Owners also get the invite/trusted roster (key omitted otherwise, like `undefined`).
      if is_owner
        response[:roster] = Db.query(
          "SELECT cm.user_id, cm.role, cm.created_at, u.username
         FROM channel_contributors cm
         JOIN users u ON u.id = cm.user_id
         WHERE cm.channel_id = $1
         ORDER BY cm.created_at ASC",
          [channel["id"]]
        ).rows
      end

      render json: response
    end

    # POST /api/contributions/:id/review (owner only)
    def review
      uid = auth_user_id_or_401
      return unless Js.truthy?(uid)

      action = body["action"]
      review_note = body["review_note"]
      if action != "accept" && action != "decline"
        return render(json: { error: "action must be 'accept' or 'decline'" }, status: 400)
      end

      status, payload = Db.transaction do
        contribution = Db.one(
          "SELECT cc.*, c.owner_id
       FROM channel_contributions cc
       JOIN channels c ON c.id = cc.channel_id
       WHERE cc.id = $1
       FOR UPDATE OF cc",
          [params[:id]]
        )

        if contribution.nil?
          next [404, { error: "Contribution not found" }]
        end
        if contribution["owner_id"] != uid
          next [403, { error: "Only the channel owner can review contributions" }]
        end
        if contribution["status"] != "pending"
          next [409, { error: "Contribution is already #{contribution['status']}" }]
        end

        new_status = action == "accept" ? "accepted" : "declined"
        updated = Db.one(
          "UPDATE channel_contributions
       SET status = $2, review_note = $3, reviewed_at = now()
       WHERE id = $1
       RETURNING *",
          [contribution["id"], new_status, trim_or_null(review_note)]
        )

        schedule_item_id = new_status == "accepted" ? materialize_contribution(contribution) : nil

        [200, updated.merge("schedule_item_id" => schedule_item_id)]
      end

      render json: payload, status: status
    end

    # POST /api/contributions/:id/withdraw (contributor only, while pending)
    def withdraw
      uid = auth_user_id_or_401
      return unless Js.truthy?(uid)

      result = Db.query(
        "UPDATE channel_contributions
       SET status = 'withdrawn', reviewed_at = now()
       WHERE id = $1 AND contributor_id = $2 AND status = 'pending'
       RETURNING *",
        [params[:id], uid]
      )
      if result.row_count.zero?
        return render(json: { error: "No pending contribution of yours with that id" }, status: 404)
      end

      render json: result.rows[0]
    end

    # GET /api/contributions/mine
    def mine
      uid = auth_user_id_or_401
      return unless Js.truthy?(uid)

      rows = Db.query(
        "SELECT cc.*,
              c.slug AS channel_slug,
              COALESCE(c.display_name, c.name) AS channel_name,
              f.title AS film_title
       FROM channel_contributions cc
       JOIN channels c ON c.id = cc.channel_id
       JOIN films f ON f.id = cc.film_id
       WHERE cc.contributor_id = $1
       ORDER BY cc.created_at DESC",
        [uid]
      ).rows

      render json: rows
    end

    # GET /api/channels/:slug/contributors (public)
    def contributors
      channel = find_channel_by_slug(params[:slug].to_s)
      return render(json: { error: "Channel not found" }, status: 404) unless channel

      rows = Db.query(
        "SELECT u.id, u.username,
              COUNT(*)::int AS accepted_count,
              MAX(cc.reviewed_at) AS last_accepted_at
       FROM channel_contributions cc
       JOIN users u ON u.id = cc.contributor_id
       WHERE cc.channel_id = $1 AND cc.status = 'accepted'
       GROUP BY u.id, u.username
       ORDER BY accepted_count DESC, last_accepted_at DESC",
        [channel["id"]]
      ).rows

      render json: { contribution_policy: channel["contribution_policy"], contributors: rows }
    end

    # POST /api/channels/:slug/contributors (owner only)
    def add_contributor
      uid = auth_user_id_or_401
      return unless Js.truthy?(uid)

      username = body["username"]
      role = body["role"]
      # `username?.trim()` throws on non-strings (Express: unhandled rejection).
      raise TypeError, "username.trim is not a function" unless username.nil? || username.is_a?(String)
      if username.nil? || js_trim(username).empty?
        return render(json: { error: "username is required" }, status: 400)
      end
      contributor_role = role == "trusted" ? "trusted" : "contributor"

      channel = find_channel_by_slug(params[:slug].to_s)
      return render(json: { error: "Channel not found" }, status: 404) unless channel
      if channel["owner_id"] != uid
        return render(json: { error: "Only the channel owner can manage contributors" }, status: 403)
      end

      user = Db.query("SELECT id, username FROM users WHERE username = $1 LIMIT 1", [js_trim(username)])
      return render(json: { error: "User not found" }, status: 404) if user.row_count.zero?

      row = Db.one(
        "INSERT INTO channel_contributors (channel_id, user_id, role, invited_by)
       VALUES ($1, $2, $3, $4)
       ON CONFLICT (channel_id, user_id) DO UPDATE SET role = EXCLUDED.role
       RETURNING *",
        [channel["id"], user.rows[0]["id"], contributor_role, uid]
      )

      render json: row.merge("username" => user.rows[0]["username"]), status: 201
    end

    # DELETE /api/channels/:slug/contributors/:userId (owner only)
    def remove_contributor
      uid = auth_user_id_or_401
      return unless Js.truthy?(uid)

      channel = find_channel_by_slug(params[:slug].to_s)
      return render(json: { error: "Channel not found" }, status: 404) unless channel
      if channel["owner_id"] != uid
        return render(json: { error: "Only the channel owner can manage contributors" }, status: 403)
      end

      Db.query(
        "DELETE FROM channel_contributors WHERE channel_id = $1 AND user_id = $2",
        [channel["id"], params[:userId]]
      )
      render json: { success: true }
    end

    private

    # authUserIdOr401: re-reads the bearer token (after authenticateToken).
    # Returns the token's id; when that id is falsy Express sent no response
    # at all (the request hung) -- here the action then renders nothing (204).
    def auth_user_id_or_401
      header = request.authorization.to_s
      token = header.start_with?("Bearer ") ? header[7..] : nil
      if Js.falsy?(token)
        render json: { error: "Access Denied" }, status: 401
        return nil
      end
      JsonWebToken.decode(token)["id"]
    rescue JWT::DecodeError
      render json: { error: "Invalid Token" }, status: 401
      nil
    end

    def find_channel_by_slug(slug)
      Db.one("SELECT id, owner_id, contribution_policy FROM channels WHERE slug = $1 LIMIT 1", [slug])
    end

    # Insert an accepted contribution's proposed slot into channel_schedule,
    # keeping a contribution_id pointer back for attribution.
    def materialize_contribution(contribution)
      slot = contribution["proposed_slot"]
      return nil if Js.falsy?(prop(slot, "scheduled_at"))

      film = Db.one("SELECT title FROM films WHERE id = $1", [contribution["film_id"]])
      title = film && film["title"]

      inserted = Db.one(
        "INSERT INTO channel_schedule
       (channel_id, film_id, title, scheduled_at, duration_seconds, status, recurrence_type, recurrence_days, recurrence_end_date, air_time, contribution_id)
     VALUES ($1, $2, $3, $4, $5, 'scheduled', $6, $7, $8, $9, $10)
     ON CONFLICT (channel_id, scheduled_at)
     DO UPDATE SET
       film_id = EXCLUDED.film_id,
       title = EXCLUDED.title,
       duration_seconds = EXCLUDED.duration_seconds,
       recurrence_type = EXCLUDED.recurrence_type,
       recurrence_days = EXCLUDED.recurrence_days,
       recurrence_end_date = EXCLUDED.recurrence_end_date,
       air_time = EXCLUDED.air_time,
       contribution_id = EXCLUDED.contribution_id
     RETURNING id",
        [
          contribution["channel_id"],
          contribution["film_id"],
          title,
          slot["scheduled_at"],
          slot["duration_seconds"],
          slot["recurrence_type"].nil? ? "once" : slot["recurrence_type"],
          slot["recurrence_days"],
          slot["recurrence_end_date"],
          slot["air_time"],
          contribution["id"]
        ]
      )
      inserted && inserted["id"]
    end

    def prop(obj, key)
      obj.is_a?(Hash) ? obj[key] : nil
    end

    # `value?.trim() || null` (throws on non-strings, like JS).
    def trim_or_null(value)
      return nil if value.nil?
      raise TypeError, "value.trim is not a function" unless value.is_a?(String)

      trimmed = js_trim(value)
      trimmed.empty? ? nil : trimmed
    end

    # String.prototype.trim (also strips Unicode whitespace, unlike String#strip).
    def js_trim(value)
      value.gsub(/\A[\s ﻿  -     　]+|[\s ﻿  -     　]+\z/, "")
    end
  end
end
