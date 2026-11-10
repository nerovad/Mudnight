# Port of backend/src/controllers/adminController.ts + routes/adminRoutes.ts.
# Every route requires authenticateToken + requireGroup('super_admin').
module Api
  class AdminController < ApplicationController
    VALID_GROUPS = %w[super_admin network general_user].freeze

    before_action :authenticate_token!
    before_action -> { require_group!("super_admin") }

    # GET /api/admin/channels
    def channels
      rows = Db.query(
        "SELECT c.id, c.slug, c.name, c.display_name, c.channel_number, c.stream_url,
              c.tags, c.created_at, c.owner_id,
              u.username as owner_name
       FROM channels c
       LEFT JOIN users u ON c.owner_id = u.id
       ORDER BY c.id"
      ).rows
      render json: rows
    rescue StandardError => e
      server_error("List channels error", e)
    end

    # PUT /api/admin/channels/:channelId
    def update_channel
      channel_id = params[:channelId]
      b = body

      row = Db.one(
        "UPDATE channels
       SET name = COALESCE($1, name),
           display_name = COALESCE($2, display_name),
           channel_number = COALESCE($3, channel_number)
       WHERE id = $4
       RETURNING id, slug, name, display_name, channel_number",
        [Js.truthy?(b["name"]) ? b["name"] : nil, Js.truthy?(b["display_name"]) ? b["display_name"] : nil,
         b["channel_number"], channel_id]
      )
      return render json: { error: "Channel not found" }, status: :not_found unless row

      render json: row
    rescue StandardError => e
      server_error("Admin update channel error", e)
    end

    # DELETE /api/admin/channels/:channelId
    def destroy_channel
      channel_id = params[:channelId]
      not_found = false

      Db.transaction do
        ch = Db.query("SELECT id FROM channels WHERE id = $1", [channel_id])
        if ch.rows.empty?
          not_found = true
          raise ActiveRecord::Rollback
        end

        Db.query("DELETE FROM channel_schedule WHERE channel_id = $1", [channel_id])
        Db.query(
          "DELETE FROM tournament_matchups WHERE session_id IN (
           SELECT id FROM sessions WHERE channel_id = $1
         )",
          [channel_id]
        )
        Db.query(
          "DELETE FROM session_entries WHERE session_id IN (
           SELECT id FROM sessions WHERE channel_id = $1
         )",
          [channel_id]
        )
        Db.query("DELETE FROM sessions WHERE channel_id = $1", [channel_id])
        Db.query("DELETE FROM channels WHERE id = $1", [channel_id])
      end

      return render json: { error: "Channel not found" }, status: :not_found if not_found

      render json: { success: true }
    rescue StandardError => e
      server_error("Admin delete channel error", e)
    end

    # GET /api/admin/users
    def users
      rows = Db.query("SELECT id, username, email, user_group, created_at FROM users ORDER BY id").rows
      render json: rows
    rescue StandardError => e
      server_error("List users error", e)
    end

    # DELETE /api/admin/users/:userId
    def destroy_user
      user_id = params[:userId]

      # Prevent deleting yourself
      if !Js.parse_int(user_id).nil? && Js.parse_int(user_id) == current_user_id
        return render json: { error: "Cannot delete your own account" }, status: :bad_request
      end

      target = Db.query("SELECT user_group FROM users WHERE id = $1", [user_id])
      return render json: { error: "User not found" }, status: :not_found if target.rows.empty?

      if target.rows[0]["user_group"] == "super_admin"
        count = Db.one("SELECT COUNT(*) FROM users WHERE user_group = 'super_admin' AND id != $1", [user_id])
        if Js.parse_int(count["count"]) == 0
          return render json: { error: "Cannot delete the last super_admin" }, status: :bad_request
        end
      end

      Db.transaction do
        channel_ids = Db.query("SELECT id FROM channels WHERE owner_id = $1", [user_id]).rows.map { |r| r["id"] }

        if channel_ids.any?
          session_ids = Db.query("SELECT id FROM sessions WHERE channel_id = ANY($1)", [channel_ids]).rows.map { |r| r["id"] }

          if session_ids.any?
            entry_ids = Db.query("SELECT id FROM session_entries WHERE session_id = ANY($1)", [session_ids]).rows.map { |r| r["id"] }

            if entry_ids.any?
              # Clear winner_entry_id refs (no CASCADE on this FK)
              Db.query("UPDATE matches SET winner_entry_id = NULL WHERE winner_entry_id = ANY($1)", [entry_ids])
              Db.query("DELETE FROM match_votes WHERE match_id IN (SELECT id FROM matches WHERE session_id = ANY($1))", [session_ids])
              Db.query("DELETE FROM matches WHERE session_id = ANY($1)", [session_ids])
              Db.query("DELETE FROM ratings WHERE session_id = ANY($1)", [session_ids])
              Db.query("DELETE FROM ballots WHERE session_id = ANY($1)", [session_ids])
              Db.query("DELETE FROM session_entries WHERE session_id = ANY($1)", [session_ids])
            end

            Db.query("DELETE FROM sessions WHERE channel_id = ANY($1)", [channel_ids])
          end

          Db.query("DELETE FROM channels WHERE owner_id = $1", [user_id])
        end

        # Delete the user (remaining FKs cascade or set null)
        Db.query("DELETE FROM users WHERE id = $1", [user_id])
      end

      render json: { success: true }
    rescue StandardError => e
      Rails.logger.error("Delete user error: #{e.message}")
      message = js_error_message(e)
      render json: { error: message.to_s.empty? ? "Server error" : message }, status: :internal_server_error
    end

    # GET /api/admin/channels/:channelId/analytics
    def channel_analytics
      channel_id = params[:channelId]
      channel = Db.one(
        "SELECT c.id, c.display_name, c.name, c.channel_number, c.created_at, c.owner_id,
              u.username as owner_name
       FROM channels c
       LEFT JOIN users u ON c.owner_id = u.id
       WHERE c.id = $1",
        [channel_id]
      )
      return render json: { error: "Channel not found" }, status: :not_found unless channel

      analytics = ChannelAnalytics.build(Js.parse_int(channel_id))
      render json: { "channel" => channel }.merge(analytics)
    rescue StandardError => e
      server_error("Admin channel analytics error", e)
    end

    # PUT /api/admin/users/:userId/group
    def update_user_group
      user_id = params[:userId]
      user_group = body["userGroup"]

      unless VALID_GROUPS.include?(user_group)
        return render json: { error: "Invalid group. Must be one of: #{VALID_GROUPS.join(', ')}" }, status: :bad_request
      end

      # Prevent removing the last super_admin
      if user_group != "super_admin"
        count = Db.one("SELECT COUNT(*) FROM users WHERE user_group = 'super_admin' AND id != $1", [user_id])
        target = Db.one("SELECT user_group FROM users WHERE id = $1", [user_id])
        if target&.dig("user_group") == "super_admin" && Js.parse_int(count["count"]) == 0
          return render json: { error: "Cannot remove the last super_admin" }, status: :bad_request
        end
      end

      row = Db.one(
        "UPDATE users SET user_group = $1 WHERE id = $2 RETURNING id, username, email, user_group",
        [user_group, user_id]
      )
      return render json: { error: "User not found" }, status: :not_found unless row

      render json: row
    rescue StandardError => e
      server_error("Update user group error", e)
    end

    private

    def server_error(label, error)
      Rails.logger.error("#{label}: #{error.message}")
      render json: { error: "Server error" }, status: :internal_server_error
    end

    # node-postgres error.message is the primary message only (no "ERROR:" /
    # LINE context), which deleteUser returns to the client.
    def js_error_message(error)
      if error.is_a?(Db::Error) && error.pg_error.respond_to?(:result) && error.pg_error.result
        error.pg_error.result.error_field(PG::Result::PG_DIAG_MESSAGE_PRIMARY) || error.message
      else
        error.message
      end
    end
  end
end
