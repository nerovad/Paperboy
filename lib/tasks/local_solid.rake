# frozen_string_literal: true

namespace :local_solid do
  desc 'Create workstation Solid SQLite databases and load their schemas'
  task prepare: :environment do
    abort 'Set PAPERBOY_LOCAL_SOLID=1 before preparing local Solid databases' unless ENV['PAPERBOY_LOCAL_SOLID'] == '1'

    %w[queue cache cable].each do |name|
      ActiveRecord::Tasks::DatabaseTasks.with_temporary_pool_for_each(env: Rails.env, name: name) do
        ActiveRecord::Tasks::DatabaseTasks.migrate
      end
    end
  end
end
