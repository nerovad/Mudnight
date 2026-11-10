# A channel creator's plugin config: which plugins their channel runs and
# with what settings. Viewers may layer their own changes on top, as far as
# each plugin's policy allows (shared/src/plugins/resolve.ts).
module Api
  class ChannelPluginsController < ApplicationController
    before_action :authenticate_token!, only: :update

    # GET /api/channels/:slug/plugins
    def show
      row = Db.one("SELECT owner_id, plugins FROM channels WHERE slug = $1", [params[:slug]])
      return render(json: { error: "Channel not found" }, status: :not_found) unless row

      render json: { owner_id: row["owner_id"], plugins: row["plugins"] || [] }
    end

    # PUT /api/channels/:slug/plugins { plugins: [{ id, enabled, settings }] }
    def update
      row = Db.one("SELECT id, owner_id FROM channels WHERE slug = $1", [params[:slug]])
      return render(json: { error: "Channel not found" }, status: :not_found) unless row
      unless row["owner_id"] == current_user_id
        return render(json: { error: "Only the channel owner can change its plugins" }, status: :forbidden)
      end

      installs, error = PluginManifest.validate_installs(body["plugins"])
      return render(json: { error: error }, status: :bad_request) unless installs

      Db.query("UPDATE channels SET plugins = $1 WHERE id = $2", [JSON.generate(installs), row["id"]])
      render json: { owner_id: row["owner_id"], plugins: installs }
    end
  end
end
