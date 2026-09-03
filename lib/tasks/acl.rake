# frozen_string_literal: true

# Mirrors the ACL definitions and group memberships across
# Paperboy_Dev / _Stage / _Prod:
#
#   dev$   bin/rails acl:dump MERGE=1     # add dev's groups, grants and members
#   dev$   git commit db/acl.yml
#   stage$ bin/rails acl:sync DRY_RUN=1   # read the plan
#   stage$ bin/rails acl:sync             # apply it, then the same in prod
#
# The work lives in Paperboy::AclSeed (dump, merge) and its Sync half (apply).
namespace :acl do
  desc 'Dump this environment ACL definitions and memberships to db/acl.yml. MERGE=1 unions them into the existing file instead of overwriting'
  task dump: :environment do
    merging = ENV['MERGE'].present? && Paperboy::AclSeed::PATH.exist?
    new_org = merging ? Paperboy::AclSeed.org_delta.size : 0
    snapshot = Paperboy::AclSeed.snapshot
    # Contractor memberships cannot travel; AclSeed.membership_rows says why.
    skipped = EmployeeGroup.count - snapshot['memberships'].size
    snapshot = Paperboy::AclSeed.merge(Paperboy::AclSeed.load_file, snapshot) if merging
    Paperboy::AclSeed::PATH.write(snapshot.to_yaml)

    grants = snapshot['groups'].sum { |group| group['permissions'].size }
    puts "#{merging ? 'Merged' : 'Wrote'} #{Paperboy::AclSeed::PATH} from #{ActiveRecord::Base.connection.current_database}"
    puts "  #{snapshot['groups'].size} groups, #{grants} grants, #{snapshot['org_permissions'].size} org grants, #{snapshot['memberships'].size} memberships"
    puts "  #{new_org} org grants here were not in the file — read the diff before committing" if new_org.positive?
    puts "  #{skipped} contractor membership#{'s' unless skipped == 1} skipped — contractor ids are local to this database" if skipped.positive?
  end

  desc 'List org_permissions present in this environment but missing from db/acl.yml'
  task org_delta: :environment do
    rows = Paperboy::AclSeed.org_delta
    puts "#{rows.size} org grants in #{ActiveRecord::Base.connection.current_database} are not in db/acl.yml"
    rows.each do |row|
      scope = [row['agency_id'], row['division_id'], row['department_id'], row['unit_id']].compact.join('/')
      puts "  #{scope} → #{row['type']}/#{row['class'].presence || row['key']}"
    end
  end

  desc 'Apply db/acl.yml to this environment (additive). DRY_RUN=1 previews; PRUNE=1 also removes grants and memberships missing from the file'
  task sync: :environment do
    dry = ENV['DRY_RUN'].present?
    prune = ENV['PRUNE'].present?
    puts "#{dry ? 'Previewing' : 'Applying'} #{Paperboy::AclSeed::PATH} → #{ActiveRecord::Base.connection.current_database}#{' (prune on)' if prune}"

    log = ActiveRecord::Base.transaction { Paperboy::AclSeed::Sync.call(dry: dry, prune: prune) }
    log.each { |line| puts "  #{line}" }

    # The '!' lines are grants this database cannot hold yet, not changes made.
    changes, held = log.partition { |line| line.start_with?('+', '-', '~') }
    puts changes.empty? ? '  Already in sync.' : "  #{changes.size} change#{'s' unless changes.size == 1}#{' — nothing written (DRY_RUN)' if dry}"
    puts "  #{held.size} grant#{'s' unless held.size == 1} held back — see the ! lines above" if held.any?
  end
end
