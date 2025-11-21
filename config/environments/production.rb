require "active_support/core_ext/integer/time"

Rails.application.configure do
  # Settings specified here will take precedence over those in config/application.rb.

  config.enable_reloading = false
  config.eager_load = true

  config.consider_all_requests_local = false
  config.action_controller.perform_caching = true
  config.public_file_server.headers = { "cache-control" => "public, max-age=#{1.year.to_i}" }

  config.active_storage.service = :local

  # We’re behind nginx with HTTPS termination
  config.assume_ssl = true
  config.force_ssl  = true   # now that HTTPS works, this should be on

  config.log_tags = [:request_id]
  config.logger   = ActiveSupport::TaggedLogging.logger(STDOUT)
  config.log_level = ENV.fetch("RAILS_LOG_LEVEL", "info")
  config.silence_healthcheck_path = "/up"

  config.active_support.report_deprecations = false

  # Keep this simple for now and use file_store everywhere
  config.cache_store = :file_store, Rails.root.join("tmp/cache")

  # Sidekiq for jobs
  config.active_job.queue_adapter = :sidekiq

  # You probably want this to be your real host:
  config.action_mailer.default_url_options = { host: "gsa-forms" }

  config.i18n.fallbacks = true
  config.active_record.dump_schema_after_migration = false
  config.active_record.attributes_for_inspect = [:id]
end

