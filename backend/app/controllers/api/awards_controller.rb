# Port of routes/awardRoutes.ts -> profileController.getMyAwards.
module Api
  class AwardsController < ApplicationController
    before_action :authenticate_token!

    # GET /api/awards/mine
    def mine
      result = Db.query(
        "SELECT * FROM user_profile_awards WHERE user_id = $1 ORDER BY position, year DESC, id DESC",
        [current_user_id]
      )

      awards = result.rows.map do |a|
        { id: a["id"].to_s, name: a["name"], year: a["year"], work: a["work"], position: a["position"] }
      end

      render json: awards
    rescue StandardError => e
      Rails.logger.error("Get awards error: #{e.message}")
      render json: { error: "Server error" }, status: :internal_server_error
    end
  end
end
