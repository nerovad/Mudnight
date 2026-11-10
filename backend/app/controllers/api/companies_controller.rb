# Port of routes/companyRoutes.ts -> profileController.getMyCompanies.
module Api
  class CompaniesController < ApplicationController
    before_action :authenticate_token!

    # GET /api/companies/mine
    def mine
      result = Db.query(
        "SELECT * FROM user_profile_companies WHERE user_id = $1 ORDER BY position, id DESC",
        [current_user_id]
      )

      companies = result.rows.map do |c|
        { id: c["id"].to_s, name: c["name"], role: c["role"], website: c["website"], position: c["position"] }
      end

      render json: companies
    rescue StandardError => e
      Rails.logger.error("Get companies error: #{e.message}")
      render json: { error: "Server error" }, status: :internal_server_error
    end
  end
end
