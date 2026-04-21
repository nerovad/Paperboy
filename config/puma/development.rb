APP_DIR = "/home/matthew/gitea/Paperboy"

threads_count = ENV.fetch("RAILS_MAX_THREADS", 3)
threads threads_count, threads_count

environment "development"

bind "tcp://127.0.0.1:3001"

pidfile     "#{APP_DIR}/tmp/pids/puma.pid"
state_path  "#{APP_DIR}/tmp/pids/puma.state"

stdout_redirect "#{APP_DIR}/log/puma.stdout.log",
                "#{APP_DIR}/log/puma.stderr.log",
                true

plugin :tmp_restart
