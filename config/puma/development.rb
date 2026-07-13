# frozen_string_literal: true

app_dir = ENV.fetch('APP_DIR', File.expand_path('../..', __dir__))

threads_count = ENV.fetch('RAILS_MAX_THREADS', 3)
threads threads_count, threads_count

environment 'development'

bind 'tcp://127.0.0.1:3001'

pidfile     "#{app_dir}/tmp/pids/puma.pid"
state_path  "#{app_dir}/tmp/pids/puma.state"

stdout_redirect "#{app_dir}/log/puma.stdout.log",
                "#{app_dir}/log/puma.stderr.log",
                true

plugin :tmp_restart
