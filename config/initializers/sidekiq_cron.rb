# frozen_string_literal: true

# Local development (bin/dev-local) sets PAPERBOY_DISABLE_CRON so a workstation
# Sidekiq does not race the dev server's scheduled jobs against the shared
# Paperboy_Dev database. Unset everywhere else, so servers keep their schedule.
unless ENV['PAPERBOY_DISABLE_CRON'] == 'true'
  Sidekiq.configure_server do
    schedule_file = 'config/sidekiq_cron_schedule.yml'

    Sidekiq::Cron::Job.load_from_hash! YAML.load_file(schedule_file) if File.exist?(schedule_file)
  end
end
