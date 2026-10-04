# frozen_string_literal: true

require_relative 'boot'

require 'rails/all'

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

# dotenv leaves .env.local out of the test environment. Here it is where a
# machine names its own PAPERBOY_TEST_DATABASE, because .env is a verbatim copy
# of LockBox (bin/env-pull), so the suite has to read it too.
Dotenv::Rails.files.insert(1, '.env.local') if Rails.env.test?

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
    # config.eager_load_paths << Rails.root.join("extras")
    config.active_job.queue_adapter = :solid_queue
    config.middleware.use ActionDispatch::Cookies
    config.middleware.use ActionDispatch::Session::CookieStore
  end
end
