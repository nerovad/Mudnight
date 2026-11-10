# Route table ported 1:1 from the Express server (backend/src/server.ts and
# backend/src/routes/*.ts). Paths, HTTP verbs, param names (camelCase, as in
# Express) and ordering are kept so the React and mobile clients need no
# changes. Each block notes the Express router it replaces.
Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  DIGITS = /\d+/

  scope "/api", module: "api", format: false, defaults: { format: :json } do
    # authRoutes.ts
    scope "/auth", controller: "auth" do
      post "register", action: :register
      post "login", action: :login
      post "refresh", action: :refresh
      post "forgot-password", action: :forgot_password
      post "change-password", action: :change_password
    end

    # directMessageRoutes.ts (chatRoutes' GET /messages/messages was shadowed
    # by GET /messages/:userId in Express and is unused; chat history now
    # arrives over ActionCable, see ChatChannel)
    scope "/messages", controller: "direct_messages" do
      get "conversations", action: :conversations
      get "users/search", action: :search_users
      post "send", action: :send_message
      get ":userId", action: :show
      post ":userId/read", action: :mark_read
    end

    # voteRoutes.ts
    post "ratings", to: "votes#create_rating"
    post "sessions/:sessionId/entries/:entryId/rate", to: "votes#rate_entry"
    get "sessions/:sessionId/leaderboard", to: "votes#leaderboard"

    # profileRoutes.ts
    scope "/profile", controller: "profiles" do
      get "user/:handle", action: :public_profile
      get "me", action: :me
      post "bio", action: :update_bio
      post "avatar", action: :update_avatar
    end

    # channelRoutes.ts (+ tournamentRoutes' channel bracket)
    scope "/channels" do
      get "mine", to: "channels#mine"
      get ":channelId/analytics", to: "channels#analytics", constraints: { channelId: DIGITS }
      post "/", to: "channels#create"
      get "/", to: "channels#index"
      patch ":id", to: "channels#update"
      delete ":id", to: "channels#destroy"

      get ":channelId/films", to: "films#channel_films", constraints: { channelId: DIGITS }
      get ":slug/films", to: "films#channel_films"

      get ":slug/schedule", to: "channels#schedule"
      post ":slug/schedule", to: "channels#update_schedule"

      post ":slug/contributions", to: "contributions#create"
      get ":slug/contributions", to: "contributions#channel_index"
      get ":slug/contributors", to: "contributions#contributors"
      post ":slug/contributors", to: "contributions#add_contributor"
      delete ":slug/contributors/:userId", to: "contributions#remove_contributor", constraints: { userId: DIGITS }

      post ":slug/media", to: "media#create"
      get ":slug/media", to: "media#index"
      delete ":slug/media/:id", to: "media#destroy", constraints: { id: DIGITS }
      patch ":slug/media/:id", to: "media#update", constraints: { id: DIGITS }

      get ":slug/segments", to: "segments#index"
      post ":slug/segments", to: "segments#create"
      post ":slug/segments/reorder", to: "segments#reorder"
      patch ":slug/segments/:id", to: "segments#update", constraints: { id: DIGITS }
      delete ":slug/segments/:id", to: "segments#destroy", constraints: { id: DIGITS }

      post ":slug/playout/provision", to: "playout#provision"
      post ":slug/playout/tune", to: "playout#tune"
      get ":slug/playout/config", to: "playout#show_config"

      get ":slug", to: "channels#show"

      get ":channelId/tournament", to: "tournaments#show"
    end

    # festivalRoutes.ts (session controls)
    scope "/festivals", controller: "festivals" do
      post "/", action: :create
      post ":sessionId/start", action: :start
      post ":sessionId/close", action: :close
      post ":sessionId/entries", action: :add_entry
      get ":sessionId/lineup", action: :lineup
    end

    # filmRoutes.ts
    scope "/films", controller: "films" do
      get "mine", action: :mine
      post "/", action: :create
      get "/", action: :index
    end

    # awardRoutes.ts / companyRoutes.ts
    get "awards/mine", to: "awards#mine"
    get "companies/mine", to: "companies#mine"

    # tournamentRoutes.ts
    scope "/tournaments", controller: "tournaments" do
      post "matchups/:matchupId/vote", action: :vote
      get ":sessionId/status", action: :status
      post ":sessionId/voting/start", action: :start_voting
      post ":sessionId/voting/end", action: :end_voting
      post "matchups/:matchupId/advance", action: :advance
      post "rounds/:sessionId/:roundNumber/advance-all", action: :advance_all
      delete "matchups/:matchupId/vote", action: :remove_vote
    end

    # rtmpRoutes.ts (nginx-rtmp on_publish callback)
    post "rtmp/auth", to: "rtmp#auth"

    # playoutRoutes.ts (ffplayout as-run log + playlist fetch)
    post "playout/asrun", to: "playout#asrun"
    get "playout/pl/:token/:year/:month/:date", to: "playout#playlist",
      constraints: { token: %r{[^/]+}, date: %r{[^/]+} }

    # adminRoutes.ts (super_admin only)
    scope "/admin", controller: "admin" do
      get "users", action: :users
      put "users/:userId/group", action: :update_user_group
      delete "users/:userId", action: :destroy_user
      get "channels", action: :channels
      put "channels/:channelId", action: :update_channel
      get "channels/:channelId/analytics", action: :channel_analytics
      delete "channels/:channelId", action: :destroy_channel
    end

    # savedChannelRoutes.ts
    scope "/saved-channels", controller: "saved_channels" do
      get "/", action: :index
      post ":slug", action: :create
      delete ":slug", action: :destroy
    end

    # contributionRoutes.ts
    scope "/contributions", controller: "contributions" do
      get "mine", action: :mine
      post ":id/review", action: :review, constraints: { id: DIGITS }
      post ":id/withdraw", action: :withdraw, constraints: { id: DIGITS }
    end

    # tickerRoutes.ts
    scope "/ticker", controller: "ticker" do
      get "/", action: :index
      get "all", action: :all
      post "/", action: :create
      put ":id", action: :update, constraints: { id: DIGITS }
      delete ":id", action: :destroy, constraints: { id: DIGITS }
    end
  end
end
