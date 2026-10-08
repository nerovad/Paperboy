# frozen_string_literal: true

namespace :ci do
  desc 'Empty the pre-made _CI test database and load db/schema.rb (never creates or drops a database)'
  task reset_database: :environment do
    db_config = ActiveRecord::Base.configurations.configs_for(env_name: 'test', name: 'primary')
    Paperboy::CiDatabase.reset!(db_config)
    puts "Reset #{db_config.database} and loaded the schema."
  end
end
