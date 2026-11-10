# A signed-in viewer's plugin overrides: themes they want on every channel,
# plugins they've added, things they've turned off. Signed-out viewers keep
# the same shape in localStorage.
module Api
  class PluginPrefsController < ApplicationController
    before_action :authenticate_token!

    # GET /api/plugin-prefs
    def show
      row = Db.one("SELECT prefs FROM user_plugin_prefs WHERE user_id = $1", [current_user_id])
      prefs = row ? row["prefs"] : {}
      render json: { "global" => prefs["global"] || {}, "channels" => prefs["channels"] || {} }
    end

    # PUT /api/plugin-prefs { global, channels }
    def update
      prefs, error = PluginManifest.validate_prefs(body)
      return render(json: { error: error }, status: :bad_request) unless prefs

      Db.query(<<~SQL, [current_user_id, JSON.generate(prefs)])
        INSERT INTO user_plugin_prefs (user_id, prefs) VALUES ($1, $2)
        ON CONFLICT (user_id) DO UPDATE SET prefs = EXCLUDED.prefs, updated_at = now()
      SQL
      render json: prefs
    end
  end
end
