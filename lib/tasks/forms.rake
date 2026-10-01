# frozen_string_literal: true

# Mirrors the form definitions -- templates, their fields and their workflow
# (statuses, routing, emails, email rules, copy recipients) -- across
# Paperboy_Dev / _Stage / _Prod, with dev as the source of truth:
#
#   dev$   bin/rails forms:dump MERGE=1    # add dev's forms to the file
#   dev$   git commit db/forms.yml
#   stage$ bin/rails forms:sync DRY_RUN=1  # read the plan
#   stage$ bin/rails forms:sync            # apply it, then the same in prod
#
# The work lives in Paperboy::FormSeed (dump, merge), its Sync half (apply)
# and FormSeed::Workflow (both, for the workflow rows).
namespace :forms do
  desc 'Dump this environment form templates, fields and workflow to db/forms.yml. MERGE=1 unions them into the existing file instead of overwriting'
  task dump: :environment do
    merging = ENV['MERGE'].present? && Paperboy::FormSeed::PATH.exist?
    snapshot = Paperboy::FormSeed.snapshot
    snapshot = Paperboy::FormSeed.merge(Paperboy::FormSeed.load_file, snapshot) if merging
    Paperboy::FormSeed::PATH.write(snapshot.to_yaml)

    fields = snapshot['forms'].sum { |form| Array(form['fields']).size }
    puts "#{merging ? 'Merged' : 'Wrote'} #{Paperboy::FormSeed::PATH} from #{ActiveRecord::Base.connection.current_database}"
    puts "  #{snapshot['forms'].size} forms, #{fields} fields"
  end

  desc 'Apply db/forms.yml to this environment: creates missing forms, matches their workflow, adds fields. DRY_RUN=1 previews; PRUNE=1 also removes fields missing from the file'
  task sync: :environment do
    dry = ENV['DRY_RUN'].present?
    prune = ENV['PRUNE'].present?
    # Wired into bin/deploy under `set -e`, so a file that is not there yet is
    # a no-op with a note rather than the exception FormSeed.load_file raises.
    unless Paperboy::FormSeed::PATH.exist?
      puts "#{Paperboy::FormSeed::PATH} not found — nothing to sync (run `bin/rails forms:dump` on dev first)"
      next
    end

    puts "#{dry ? 'Previewing' : 'Applying'} #{Paperboy::FormSeed::PATH} → " \
         "#{ActiveRecord::Base.connection.current_database}#{' (prune on)' if prune}"

    # A dry run writes nothing; the rollback makes that true whatever Sync does.
    log = nil
    ActiveRecord::Base.transaction do
      log = Paperboy::FormSeed::Sync.call(dry: dry, prune: prune)
      raise ActiveRecord::Rollback if dry
    end
    log.each { |line| puts "  #{line}" }

    # The '!' lines are definitions this database cannot hold, not changes made.
    changes, held = log.partition { |line| line.start_with?('+', '-', '~') }
    puts changes.empty? ? '  Already in sync.' : "  #{changes.size} change#{'s' unless changes.size == 1}#{' — nothing written (DRY_RUN)' if dry}"
    puts "  #{held.size} definition#{'s' unless held.size == 1} held back — see the ! lines above" if held.any?
  end
end
