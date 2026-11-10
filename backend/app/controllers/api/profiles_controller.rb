# Port of backend/src/controllers/profileController.ts + routes/profileRoutes.ts
# (getMyFilms lives in FilmsController).
module Api
  class ProfilesController < ApplicationController
    # profileRoutes: GET /user/:handle is public, everything after
    # router.use(authenticateToken) requires a token.
    before_action :authenticate_token!, except: :public_profile

    STATS_QUERY = <<~SQL.freeze
      SELECT
        (SELECT COUNT(*) FROM follows WHERE following_id = $1) as followers_count,
        (SELECT COUNT(*) FROM follows WHERE follower_id = $1) as following_count,
        (SELECT COUNT(*) FROM user_profile_film_links WHERE user_id = $1) as films_count,
        (SELECT COUNT(*) FROM user_profile_awards WHERE user_id = $1) as awards_count
    SQL

    # GET /api/profile/me
    def me
      with_server_error("Get profile error") do
        user_id = current_user_id

        user = Db.one("SELECT id, username, email, user_group FROM users WHERE id = $1", [user_id])
        next render(json: { error: "User not found" }, status: :not_found) unless user

        # Get profile data from user_profiles table
        profile = Db.one("SELECT * FROM user_profiles WHERE user_id = $1", [user_id]) || {}

        # Get socials
        socials = Db.query("SELECT label, url FROM user_profile_socials WHERE user_id = $1 ORDER BY position", [user_id]).rows

        stats = Db.one(STATS_QUERY, [user_id]) || {}

        handle = Js.truthy?(profile["handle"]) ? profile["handle"] : "@#{user['username']}"
        profile_data = {
          id: user["id"].to_s,
          handle: handle,
          displayName: handle, # Use @username as display name
          userGroup: Js.truthy?(user["user_group"]) ? user["user_group"] : "general_user"
        }
        # JSON.stringify drops undefined: without a user_profiles row these
        # keys are absent rather than null.
        { bannerUrl: "banner_url", avatarUrl: "avatar_url", bio: "bio", location: "location", website: "website" }.each do |key, column|
          profile_data[key] = profile[column] if profile.key?(column)
        end
        profile_data[:socials] = socials
        profile_data[:stats] = stats_hash(stats)

        render json: profile_data
      end
    end

    # GET /api/profile/user/:handle (public)
    def public_profile
      with_server_error("Get public profile error") do
        handle = params[:handle].to_s
        # Strip leading @ if present
        clean_handle = handle.start_with?("@") ? handle[1..] : handle

        user = Db.one(<<~SQL, [clean_handle, "@#{clean_handle}"])
          SELECT u.id, u.username, up.handle, up.banner_url, up.avatar_url, up.bio, up.location, up.website
          FROM users u
          LEFT JOIN user_profiles up ON up.user_id = u.id
          WHERE u.username ILIKE $1 OR up.handle ILIKE $2
          LIMIT 1
        SQL
        next render(json: { error: "User not found" }, status: :not_found) unless user

        user_id = user["id"]
        stats = Db.one(STATS_QUERY, [user_id]) || {}

        channels = Db.query(
          "SELECT id, name, display_name, channel_number, slug, description, thumbnail FROM channels WHERE owner_id = $1 ORDER BY channel_number",
          [user_id]
        ).rows

        handle_out = Js.truthy?(user["handle"]) ? user["handle"] : "@#{user['username']}"
        render json: {
          id: user_id.to_s,
          handle: handle_out,
          displayName: handle_out,
          bannerUrl: user["banner_url"],
          avatarUrl: user["avatar_url"],
          bio: user["bio"],
          location: user["location"],
          website: user["website"],
          stats: stats_hash(stats),
          channels: channels.map do |ch|
            {
              id: ch["id"].to_s,
              name: ch["name"],
              display_name: ch["display_name"],
              channel_number: ch["channel_number"],
              slug: ch["slug"],
              description: ch["description"],
              thumbnail: ch["thumbnail"]
            }
          end
        }
      end
    end

    # POST /api/profile/bio
    def update_bio
      with_server_error("Update bio error") do
        Db.query(<<~SQL, [current_user_id, body["bio"]])
          INSERT INTO user_profiles (user_id, bio, updated_at)
          VALUES ($1, $2, CURRENT_TIMESTAMP)
          ON CONFLICT (user_id)
          DO UPDATE SET bio = $2, updated_at = CURRENT_TIMESTAMP
        SQL

        render json: { message: "Bio updated successfully" }
      end
    end

    # POST /api/profile/avatar
    def update_avatar
      with_server_error("Update avatar error") do
        Db.query(<<~SQL, [current_user_id, body["avatarUrl"]])
          INSERT INTO user_profiles (user_id, avatar_url, updated_at)
          VALUES ($1, $2, CURRENT_TIMESTAMP)
          ON CONFLICT (user_id)
          DO UPDATE SET avatar_url = $2, updated_at = CURRENT_TIMESTAMP
        SQL

        render json: { message: "Avatar updated successfully" }
      end
    end

    private

    def stats_hash(stats)
      {
        followers: Js.parse_int(stats["followers_count"]) || 0,
        following: Js.parse_int(stats["following_count"]) || 0,
        films: Js.parse_int(stats["films_count"]) || 0,
        awards: Js.parse_int(stats["awards_count"]) || 0
      }
    end

    # The Express handlers caught their own errors: 500 {"error":"Server error"}.
    def with_server_error(label)
      yield
    rescue StandardError => e
      Rails.logger.error("#{label}: #{e.message}")
      render json: { error: "Server error" }, status: :internal_server_error
    end
  end
end
