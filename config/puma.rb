# Default Puma config for local `rails s` / `bin/dev` sessions.
# Systemd services use the per-environment configs under config/puma/.

threads_count = ENV.fetch("RAILS_MAX_THREADS", 3)
threads threads_count, threads_count

environment ENV.fetch("RAILS_ENV", "development")

port ENV.fetch("PORT", 3000)

plugin :tmp_restart
