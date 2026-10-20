# frozen_string_literal: true

namespace :ci do
  # Safe to run again, and after a crash: every run empties whatever the
  # database holds and loads db/schema.rb afresh. A run that stopped halfway
  # leaves a partly emptied database, and the next run empties the rest.
  desc 'Empty the pre-made _CI test database and load db/schema.rb (never creates or drops a database)'
  task reset_database: :environment do
    db_config = ActiveRecord::Base.configurations.configs_for(env_name: 'test', name: 'primary')
    Paperboy::CiDatabase.reset!(db_config)
    puts "Reset #{db_config.database} and loaded the schema."
  end
end
