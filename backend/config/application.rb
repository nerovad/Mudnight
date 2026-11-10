require_relative "boot"

require "rails"
require "active_model/railtie"
require "active_job/railtie"
require "active_record/railtie"
require "action_controller/railtie"
require "action_mailer/railtie"
require "action_view/railtie"
require "action_cable/engine"
require "rails/test_unit/railtie"

Bundler.require(*Rails.groups)

# The monorepo keeps one .env at its root, shared with the frontend tooling.
Dotenv.load(File.expand_path("../../.env", __dir__)) if defined?(Dotenv)

module Cinezoo
  class Application < Rails::Application
    config.load_defaults 8.1
    config.autoload_lib(ignore: %w[assets tasks])

    config.api_only = true
    config.time_zone = "UTC"

    # The schema predates Rails: it was built from hand-written SQL migrations
    # (partitioned tables, triggers, functions), so keep it as SQL.
    config.active_record.schema_format = :sql

    # The legacy migration runner already owns `schema_migrations` with its own
    # columns (filename, checksum, ...). Rails keeps its ledger alongside it.
    config.active_record.schema_migrations_table_name = "rails_schema_migrations"
    config.active_record.internal_metadata_table_name = "rails_internal_metadata"

    # Media conforms and playout calls run in-process, as they did under Node.
    config.active_job.queue_adapter = :async

    # Express (body-parser) kept nulls inside JSON arrays; so do we.
    config.action_dispatch.perform_deep_munge = false

    # ActionCable is mounted at /cable; clients connect from the Vite origin.
    config.action_cable.mount_path = "/cable"
    config.action_cable.disable_request_forgery_protection = true

    # Serve channel thumbnails and other runtime uploads from backend/uploads,
    # at the same /uploads/... URLs the Express server used.
    config.middleware.insert_before 0, Rack::Static, urls: ["/uploads"], root: Rails.root.to_s
  end
end
