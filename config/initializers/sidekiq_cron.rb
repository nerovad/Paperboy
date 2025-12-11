if defined?(Sidekiq::Cron::Job)
  schedule_file = "config/sidekiq_cron_schedule.yml"
  
  if File.exist?(schedule_file)
    Sidekiq::Cron::Job.load_from_hash! YAML.load_file(schedule_file)
  end
end
