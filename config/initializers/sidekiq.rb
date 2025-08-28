# config/initializers/sidekiq.rb
require "sidekiq"
require "sidekiq-cron"

Sidekiq.configure_server do |config|
  # Redis URL (adjust if you use a different DB/index)
  config.redis = { url: ENV.fetch("REDIS_URL", "redis://localhost:6379/0") }

  # Load cron jobs from YAML at boot (works even if you don't pass -C)
  schedule_file = Rails.root.join("config", "sidekiq.yml")
  if File.exist?(schedule_file)
    yaml = YAML.load_file(schedule_file)
    if yaml && yaml["schedule"] # note string key when using YAML.load_file
      Sidekiq::Cron::Job.load_from_hash(yaml["schedule"])
    end
  end
end

Sidekiq.configure_client do |config|
  config.redis = { url: ENV.fetch("REDIS_URL", "redis://localhost:6379/0") }
end
