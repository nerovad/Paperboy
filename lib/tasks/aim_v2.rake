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

    desc 'Copy the PDFs of rows v1 left open from its queue folders into the v2 store'
    task adopt_v1_pdfs: :environment do
      backend = ENV['AIM_V1_BACKEND_DIR'].presence || File.join(ENV.fetch('AIM_LINUX_QUEUE_BASE_PATH'), '_BACK_END')
      adopted, missing = Aim::V2Seeds.adopt_v1_pdfs(backend)
      puts "store: #{adopted} PDFs adopted from #{backend}, #{missing} rows still without one"
    end

    desc 'Close rows v1 left open as deleted (BEFORE=<time>, ACTOR=<email>)'
    task clear_v1_leftovers: :environment do
      before = Time.zone.parse(ENV.fetch('BEFORE'))
      closed = Aim::V2Seeds.clear_v1_leftovers(before, actor: ENV.fetch('ACTOR'))
      puts "closed #{closed} rows created before #{before}"
    end

    desc 'Add everyone who works AIM through a group to the Admin screen list (item a.1)'
    task seed_members: :environment do
      added = Aim::Member.seed_from_groups!(added_by: 'aim:v2:seed_members')
      puts "aim.members: #{added} added from the AIM groups"
    end

    desc 'Link open invoices owned by a name to the employee of that name'
    task link_owners: :environment do
      linked, unmatched = Aim::V2Seeds.link_owners
      puts "linked #{linked} invoices to employees"
      unmatched.each { |name, count| puts "  no single employee named #{name.inspect} (#{count} invoices)" }
    end

    desc 'Purge finished rows created before BEFORE=<time>, with their events'
    task purge_before: :environment do
      before = Time.zone.parse(ENV.fetch('BEFORE'))
      rows, events = Aim::V2Seeds.purge_before(before)
      puts "purged #{rows} finished rows and #{events} events created before #{before}"
    end
  end
end
