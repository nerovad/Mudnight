# Port of routes/savedChannelRoutes.ts (inline handlers). Errors fall through
# to the global handler (500 "Internal Server Error"), as next(err) did.
module Api
  class SavedChannelsController < ApplicationController
    before_action :authenticate_token!

    MAX_SAVED = 5

    # GET /api/saved-channels — list saved channels for the authenticated user
    def index
      rows = Db.query(<<~SQL, [current_user_id]).rows
        SELECT c.slug, c.display_name, c.name
               FROM saved_channels sc
               JOIN channels c ON c.id = sc.channel_id
               WHERE sc.user_id = $1
               ORDER BY sc.created_at ASC
      SQL
      render json: rows.map { |r| { slug: r["slug"], name: first_truthy(r["display_name"], r["name"], r["slug"]) } }
    end

    # POST /api/saved-channels/:slug — save a channel
    def create
      ch = Db.query("SELECT id FROM channels WHERE slug = $1", [params[:slug]])
      return render(json: { error: "Channel not found" }, status: :not_found) if ch.rows.empty?

      channel_id = ch.rows[0]["id"]

      # Check limit
      count_res = Db.query("SELECT count(*)::int AS cnt FROM saved_channels WHERE user_id = $1", [current_user_id])
      if count_res.rows[0]["cnt"] >= MAX_SAVED
        return render(json: { error: "You can save up to #{MAX_SAVED} channels" }, status: :bad_request)
      end

      Db.query(
        "INSERT INTO saved_channels (user_id, channel_id) VALUES ($1, $2) ON CONFLICT DO NOTHING",
        [current_user_id, channel_id]
      )
      render json: { saved: true }, status: :created
    end

    # DELETE /api/saved-channels/:slug — unsave a channel
    def destroy
      ch = Db.query("SELECT id FROM channels WHERE slug = $1", [params[:slug]])
      return render(json: { error: "Channel not found" }, status: :not_found) if ch.rows.empty?

      Db.query(
        "DELETE FROM saved_channels WHERE user_id = $1 AND channel_id = $2",
        [current_user_id, ch.rows[0]["id"]]
      )
      render json: { saved: false }
    end

    private

    # a || b || c
    def first_truthy(*values)
      values.find { |v| Js.truthy?(v) } || values.last
    end
  end
end
