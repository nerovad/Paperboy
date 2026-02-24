threads_count = ENV.fetch("RAILS_MAX_THREADS", 3)
threads threads_count, threads_count

environment ENV.fetch("RAILS_ENV", "development")

if ENV.fetch("RAILS_ENV", "development") == "production"
  # Production: bind to port 3001 (Nginx proxies to this)
  bind "tcp://127.0.0.1:3001"

  app_dir = "/home/matthew/gitea/Paperboy"
  pidfile "#{app_dir}/tmp/pids/puma.pid"
  state_path "#{app_dir}/tmp/pids/puma.state"

  # Workers (processes) — set to number of CPU cores
  workers ENV.fetch("WEB_CONCURRENCY", 2)
  preload_app!

  stdout_redirect "#{app_dir}/log/puma.stdout.log",
                  "#{app_dir}/log/puma.stderr.log",
                  true
else
  # Development: port 3000
  port ENV.fetch("PORT", 3000)
end

plugin :tmp_restart
plugin :solid_queue if ENV["SOLID_QUEUE_IN_PUMA"]
