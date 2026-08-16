# frozen_string_literal: true

# Mirrors the ACL *definitions* — groups, their permission grants, and the
# org-level grants — across Paperboy_Dev / _Stage / _Prod, which are three
# independent databases (Groups, Group_Permissions and org_permissions all
# live on the default connection, not in shared GSABSS).
#
# Deliberately NOT handled:
#   * Employee_Groups — memberships are meant to differ. Dev wants you in
#     every group to test; prod wants the real assignments.
#   * contractors — carries password_digest, which must not leave production.
#
# Groups are matched by Group_Name, never GroupID: GroupID is an identity
# column and has already diverged between the three databases.
module AclSeed
  PATH = Rails.root.join('db/acl.yml')

  module_function

  def snapshot
    { 'groups' => group_rows, 'org_permissions' => org_rows }
  end

  def group_rows
    Group.order(:group_name).map do |group|
      { 'name' => group.group_name, 'description' => group.description.presence, 'permissions' => grant_rows(group) }
    end
  end

  def grant_rows(group)
    GroupPermission.where(group_id: group.id)
                   .order(:permission_type, :permission_key)
                   .map { |perm| grant_row(perm.permission_type, perm.permission_key) }
  end

  # A 'form' grant is keyed by Forms::Template id, and those ids are per-database
  # too. Record the form name alongside so sync can verify the id still means
  # the same form in the target environment.
  def grant_row(type, key)
    row = { 'type' => type, 'key' => key }
    return row unless type == 'form'

    row.merge('label' => Forms::Template.find_by(id: key)&.name)
  end

  def org_rows
    OrgPermission.order(:agency_id, :division_id, :department_id, :unit_id, :permission_type, :permission_key).map do |perm|
      { 'agency_id' => perm.agency_id, 'division_id' => perm.division_id, 'department_id' => perm.department_id,
        'unit_id' => perm.unit_id, 'type' => perm.permission_type, 'key' => perm.permission_key }
    end
  end

  def load_file
    raise "#{PATH} not found — run `bin/rails acl:dump` against production first." unless PATH.exist?

    YAML.safe_load_file(PATH) || {}
  end

  # Union the current environment's groups and grants into what db/acl.yml
  # already holds, so the file can describe every environment at once. Group
  # names are matched case-insensitively (MSSQL collation is too).
  #
  # org_permissions are deliberately carried over from the file untouched:
  # they grant by agency/division/department/unit, so merging one environment's
  # into another widens access far more broadly than a group grant does. Use
  # acl:org_delta to see what a merge would have added.
  def merge(file_data, snapshot)
    groups = {}
    (Array(file_data['groups']) + Array(snapshot['groups'])).each do |row|
      key = row['name'].to_s.downcase
      groups[key] = groups[key] ? merge_group(groups[key], row) : row
    end
    { 'groups' => groups.values.sort_by { |group| group['name'].to_s },
      'org_permissions' => Array(file_data['org_permissions']) }
  end

  def merge_group(base, other)
    permissions = (Array(base['permissions']) + Array(other['permissions']))
                  .uniq { |perm| [perm['type'], perm['key']] }
                  .sort_by { |perm| [perm['type'].to_s, perm['key'].to_s] }
    { 'name' => base['name'], 'description' => base['description'].presence || other['description'],
      'permissions' => permissions }
  end

  # org_permissions present in this environment but absent from db/acl.yml.
  def org_delta
    have = Array(load_file['org_permissions']).to_set { |row| org_key(row['agency_id'], row['division_id'], row['department_id'], row['unit_id'], row['type'], row['key']) }
    org_rows.reject { |row| have.include?(org_key(row['agency_id'], row['division_id'], row['department_id'], row['unit_id'], row['type'], row['key'])) }
  end

  # Returns a list of human-readable change lines. Nothing is written when dry.
  def sync!(dry:, prune:)
    data = load_file
    log = Array(data['groups']).flat_map { |row| sync_group(row, dry: dry, prune: prune) }
    log + sync_org(Array(data['org_permissions']), dry: dry, prune: prune)
  end

  def sync_group(row, dry:, prune:)
    name = row['name'].to_s.strip
    return ['! group with a blank name in db/acl.yml — skipped'] if name.empty?

    log = []
    group = Group.find_by(group_name: name)
    if group
      log << backfill_description(group, row['description'], dry: dry)
    else
      log << "+ group  #{name}"
      group = Group.create!(group_name: name, description: row['description']) unless dry
    end
    log.compact + sync_grants(group, name, Array(row['permissions']), dry: dry, prune: prune)
  end

  # Descriptions are cosmetic, so fill in a blank one but never overwrite a
  # description someone has edited in this environment.
  def backfill_description(group, description, dry:)
    return nil if description.blank? || group.description.present?

    group.update!(description: description) unless dry
    "~ desc   #{group.group_name}"
  end

  def sync_grants(group, name, rows, dry:, prune:)
    labels = {}
    wanted = rows.to_set do |row|
      pair = [row['type'].to_s, row['key'].to_s]
      labels[pair] = row['label']
      pair
    end
    existing = group ? GroupPermission.where(group_id: group.id).to_set { |p| [p.permission_type, p.permission_key] } : Set.new
    additions = (wanted - existing).sort
    blocked = additions.to_h { |pair| [pair, form_mismatch(pair, labels[pair])] }
    log = additions.map do |pair|
      next "! #{name}: #{blocked[pair]}" if blocked[pair]

      type, key = pair
      GroupPermission.create!(group_id: group.id, permission_type: type, permission_key: key) unless dry
      "+ grant  #{name}: #{type}/#{key}"
    end
    return log unless prune

    log + (existing - wanted).sort.map do |type, key|
      GroupPermission.where(group_id: group.id, permission_type: type, permission_key: key).delete_all unless dry
      "- grant  #{name}: #{type}/#{key}"
    end
  end

  # Returns a reason string when a form grant must not be applied here, else nil.
  def form_mismatch(pair, label)
    type, key = pair
    return nil unless type == 'form' && label.present?

    local = Forms::Template.find_by(id: key)&.name
    return nil if local == label

    "skipped form/#{key} — #{label.inspect} in db/acl.yml but #{(local || 'nothing').inspect} here"
  end

  def sync_org(rows, dry:, prune:)
    wanted = rows.to_set { |row| org_key(row['agency_id'], row['division_id'], row['department_id'], row['unit_id'], row['type'], row['key']) }
    existing = OrgPermission.all.to_set { |p| org_key(p.agency_id, p.division_id, p.department_id, p.unit_id, p.permission_type, p.permission_key) }
    log = sorted(wanted - existing).map do |key|
      OrgPermission.create!(**org_attrs(key)) unless dry
      "+ org    #{org_label(key)}"
    end
    return log unless prune

    log + sorted(existing - wanted).map do |key|
      OrgPermission.where(**org_attrs(key)).delete_all unless dry
      "- org    #{org_label(key)}"
    end
  end

  def org_key(agency, division, department, unit, type, key)
    [agency, division, department, unit, type, key].map(&:presence)
  end

  def org_attrs(key)
    { agency_id: key[0], division_id: key[1], department_id: key[2], unit_id: key[3],
      permission_type: key[4], permission_key: key[5] }
  end

  def org_label(key)
    "#{key[0..3].compact.join('/')} → #{key[4]}/#{key[5]}"
  end

  # Org keys hold nils, so they cannot be compared directly.
  def sorted(keys)
    keys.sort_by { |key| key.map(&:to_s) }
  end
end

namespace :acl do
  desc 'Dump this environment ACL definitions to db/acl.yml. MERGE=1 unions into the existing file instead of overwriting'
  task dump: :environment do
    snapshot = AclSeed.snapshot
    merging = ENV['MERGE'].present? && AclSeed::PATH.exist?
    if merging
      skipped = AclSeed.org_delta.size
      snapshot = AclSeed.merge(AclSeed.load_file, snapshot)
      puts "  note: #{skipped} org grants here are not in db/acl.yml and were NOT merged (see acl:org_delta)" if skipped.positive?
    end
    AclSeed::PATH.write(snapshot.to_yaml)
    grants = snapshot['groups'].sum { |group| group['permissions'].size }
    puts "#{merging ? 'Merged' : 'Wrote'} #{AclSeed::PATH} from #{ActiveRecord::Base.connection.current_database}"
    puts "  #{snapshot['groups'].size} groups, #{grants} grants, #{snapshot['org_permissions'].size} org grants"
  end

  desc 'List org_permissions present in this environment but missing from db/acl.yml'
  task org_delta: :environment do
    rows = AclSeed.org_delta
    puts "#{rows.size} org grants in #{ActiveRecord::Base.connection.current_database} are not in db/acl.yml"
    rows.each { |row| puts "  #{[row['agency_id'], row['division_id'], row['department_id'], row['unit_id']].compact.join('/')} → #{row['type']}/#{row['key']}" }
  end

  desc 'Apply db/acl.yml to this environment (additive). DRY_RUN=1 previews; PRUNE=1 also removes grants missing from the file'
  task sync: :environment do
    dry = ENV['DRY_RUN'].present?
    prune = ENV['PRUNE'].present?
    puts "#{dry ? 'Previewing' : 'Applying'} #{AclSeed::PATH} → #{ActiveRecord::Base.connection.current_database}#{' (prune on)' if prune}"

    log = ActiveRecord::Base.transaction { AclSeed.sync!(dry: dry, prune: prune) }
    log.each { |line| puts "  #{line}" }
    puts log.empty? ? '  Already in sync.' : "  #{log.size} change#{'s' unless log.size == 1}#{' — nothing written (DRY_RUN)' if dry}"
  end
end
