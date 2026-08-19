# frozen_string_literal: true

# config/initializers/sidekiq.rb
require 'sidekiq'
require 'sidekiq-cron'

Sidekiq.configure_server do |config|
  # Redis URL (adjust if you use a different DB/index)
  config.redis = { url: ENV.fetch('REDIS_URL', 'redis://localhost:6379/0') }

  # Load cron jobs from YAML at boot (works even if you don't pass -C).
  # Skipped when PAPERBOY_DISABLE_CRON=true, which bin/dev-local sets so a
  # workstation Sidekiq does not run scheduled jobs against shared data.
  schedule_file = Rails.root.join('config', 'sidekiq.yml')
  if ENV['PAPERBOY_DISABLE_CRON'] != 'true' && File.exist?(schedule_file)
    yaml = YAML.load_file(schedule_file)
    Sidekiq::Cron::Job.load_from_hash(yaml['schedule']) if yaml && yaml['schedule'] # NOTE: string key when using YAML.load_file
  end
end

Sidekiq.configure_client do |config|
  config.redis = { url: ENV.fetch('REDIS_URL', 'redis://localhost:6379/0') }
end
