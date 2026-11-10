# Uploaded plugins (see docs/plugins.md). Built-in plugins ship in the web
# client and never touch this table.
#
# "unlisted" plugins don't show in the catalog but still load by key, since a
# channel that installs one has to serve it to every viewer.
module Api
  class PluginsController < ApplicationController
    before_action :authenticate_token!, only: %i[create update destroy]

    LIST_COLUMNS = "p.id, p.plugin_key, p.manifest, p.visibility, p.updated_at, p.author_id, u.username AS author"

    # GET /api/plugins — public plugins, plus the caller's own
    def index
      uid = optional_user_id
      rows = Db.query(<<~SQL, [uid]).rows
        SELECT #{LIST_COLUMNS}
        FROM plugins p JOIN users u ON u.id = p.author_id
        WHERE p.visibility = 'public' OR p.author_id = $1
        ORDER BY p.updated_at DESC
        LIMIT 500
      SQL
      render json: rows.map { |r| serialize(r, uid) }
    end

    # GET /api/plugins/bundle?ids=@a/x,@b/y — manifests and code for the
    # plugins a page is about to run
    def bundle
      ids = params[:ids].to_s.split(",").map(&:strip).select { |id| id.match?(PluginManifest::KEY_PATTERN) }.first(PluginManifest::MAX_INSTALLS * 2)
      return render(json: []) if ids.empty?

      rows = Db.query(<<~SQL, [ids]).rows
        SELECT #{LIST_COLUMNS}, p.code
        FROM plugins p JOIN users u ON u.id = p.author_id
        WHERE p.plugin_key = ANY($1)
      SQL
      render json: rows.map { |r| serialize(r, nil).merge(code: r["code"]) }
    end

    # POST /api/plugins { manifest, code, visibility? } — upload, or replace
    # your own plugin with the same id
    def create
      user = Db.one("SELECT username FROM users WHERE id = $1", [current_user_id])
      return render(json: { error: "User not found" }, status: :not_found) unless user

      code = body["code"]
      unless code.is_a?(String) && code.strip.present?
        return render(json: { error: "code is required" }, status: :bad_request)
      end
      if code.bytesize > PluginManifest::MAX_CODE_BYTES
        return render(json: { error: "code must be under #{PluginManifest::MAX_CODE_BYTES / 1024} KB" }, status: :bad_request)
      end

      manifest, errors = PluginManifest.validate(body["manifest"], user["username"])
      return render(json: { error: errors.first, errors: errors }, status: :unprocessable_entity) unless manifest

      visibility = body["visibility"] == "public" ? "public" : "unlisted"
      key = manifest["id"]

      existing = Db.one("SELECT id, author_id FROM plugins WHERE plugin_key = $1", [key])
      if existing && existing["author_id"] != current_user_id
        return render(json: { error: "#{key} belongs to someone else" }, status: :conflict)
      end

      row = Db.one(<<~SQL, [key, current_user_id, JSON.generate(manifest), code, visibility])
        INSERT INTO plugins (plugin_key, author_id, manifest, code, visibility)
        VALUES ($1, $2, $3, $4, $5)
        ON CONFLICT (plugin_key) DO UPDATE
          SET manifest = EXCLUDED.manifest, code = EXCLUDED.code,
              visibility = EXCLUDED.visibility, updated_at = now()
        RETURNING id, plugin_key, manifest, visibility, updated_at, author_id
      SQL
      render json: serialize(row.merge("author" => user["username"]), current_user_id), status: existing ? :ok : :created
    end

    # PATCH /api/plugins/:id { visibility }
    def update
      visibility = body["visibility"]
      unless %w[unlisted public].include?(visibility)
        return render(json: { error: "visibility must be 'unlisted' or 'public'" }, status: :bad_request)
      end

      row = Db.one(
        "UPDATE plugins SET visibility = $1, updated_at = now() WHERE id = $2 AND author_id = $3
         RETURNING id, plugin_key, manifest, visibility, updated_at, author_id",
        [visibility, params[:id], current_user_id]
      )
      return render(json: { error: "Plugin not found" }, status: :not_found) unless row

      render json: serialize(row, current_user_id)
    end

    # DELETE /api/plugins/:id — channels that installed it stop rendering it
    def destroy
      res = Db.query("DELETE FROM plugins WHERE id = $1 AND author_id = $2", [params[:id], current_user_id])
      return render(json: { error: "Plugin not found" }, status: :not_found) if res.row_count.zero?

      render json: { deleted: true }
    end

    private

    def serialize(row, uid)
      {
        id: row["plugin_key"],
        db_id: row["id"].to_i,
        manifest: row["manifest"],
        visibility: row["visibility"],
        author: row["author"],
        mine: !uid.nil? && row["author_id"] == uid,
        updated_at: row["updated_at"]
      }
    end
  end
end
