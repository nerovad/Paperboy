# frozen_string_literal: true

# AIM v2: the vendor aliases and rules move from JSON files in the worker
# install folder to tables. Both tasks are idempotent: run them again and
# nothing already there is changed.
#
#   bin/rails aim:v2:seed_aliases   reads vendor_aliases.json (AIM_ALIAS_DB_FILE)
#   bin/rails aim:v2:seed_rules     reads vendor_rules.json (AIM_VENDOR_RULES_FILE)
#
# A bare file name resolves under AIM_PROGRAM_DIR, translated to this server's
# mount. AIM_SEED_FILE overrides the path outright, for a copy taken elsewhere.
namespace :aim do
  namespace :v2 do
    desc 'Seed aim.vendor_aliases from the v1 vendor_aliases.json'
    task seed_aliases: :environment do
      path = Aim::V2Seeds.resolve(ENV['AIM_SEED_FILE'].presence || ENV.fetch('AIM_ALIAS_DB_FILE'))
      added, kept = Aim::V2Seeds.seed_aliases(path)
      puts "aim.vendor_aliases: #{added} added, #{kept} already present, from #{path}"
    end

    desc 'Seed aim.vendor_rules from the v1 vendor_rules.json'
    task seed_rules: :environment do
      path = Aim::V2Seeds.resolve(ENV['AIM_SEED_FILE'].presence || ENV.fetch('AIM_VENDOR_RULES_FILE'))
      added, kept = Aim::V2Seeds.seed_rules(path)
      puts "aim.vendor_rules: #{added} added, #{kept} already present, from #{path}"
    end
  end
end
