# Same origins the Express server allowed: CORS_ORIGIN is a comma-separated list.
Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins(*ENV.fetch("CORS_ORIGIN", "http://localhost:5173").split(",").map(&:strip))

    resource "*",
      headers: :any,
      methods: %i[get post put patch delete options head],
      credentials: true
  end
end
