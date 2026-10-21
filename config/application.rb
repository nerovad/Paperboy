# frozen_string_literal: true

require_relative 'boot'

require 'rails/all'

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

# dotenv leaves .env.local out of the test environment. Here it is where a
# machine names its own PAPERBOY_TEST_DATABASE, because .env is a verbatim copy
# of LockBox (bin/env-pull), so the suite has to read it too.
# A DOMAIN\user already in the process would also win: dotenv does not
# replace a set variable, and on Linux that name means Kerberos. Swap in
# the SQL login from the files before dotenv loads, so Paperboy_Test opens
# as that login. Requiring dotenv before Rails skips its railtie.
if Rails.env.test?
  Dotenv::Rails.files.insert(1, '.env.local')
  require_relative '../lib/paperboy/sql_login'
  Paperboy::SqlLogin.prefer_dotenv_sql_login!
end

module FormsApp
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 8.0

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w[assets tasks generators])

    # Configuration for the application, engines, and railties goes here.
    config.paths.add 'app/reports', eager_load: true
    config.eager_load_paths << Rails.root.join('app/reports')

    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    config.time_zone = 'Pacific Time (US & Canada)'
    config.active_job.queue_adapter = :solid_queue
    # Rails already inserts the cookie session. A second CookieStore sits
    # inside it and is the one OmniAuth writes omniauth.state into. The outer
    # store then saves the cookie without that key, so the Entra callback
    # compares the returned state to nil and crashes in secure_compare.
  end
end
