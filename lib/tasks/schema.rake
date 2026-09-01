# frozen_string_literal: true

Rake::Task['db:schema:dump'].enhance do
  next if ENV['SCHEMA_FORMAT'] == 'sql'

  sh 'bin/rubocop', '-A', 'db/schema.rb'
end
