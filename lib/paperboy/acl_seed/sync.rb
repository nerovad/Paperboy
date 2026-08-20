# frozen_string_literal: true

module Paperboy
  module AclSeed
    # Applies db/acl.yml to this database: the acl:sync half of AclSeed.
    #
    # Additive by default — a grant in the file is created here, a grant here
    # that the file does not mention is left alone. PRUNE=1 makes the file
    # authoritative and removes the extras instead. Everything runs inside one
    # transaction, and DRY_RUN=1 produces the same log without writing.
    module Sync
      module_function

      # Returns a list of human-readable change lines.
      def call(dry:, prune:)
        data = AclSeed.load_file
        forms = FormKey.index
        log = Array(data['groups']).flat_map { |row| group(row, forms, dry: dry, prune: prune) }
        log + org(Array(data['org_permissions']), forms, dry: dry, prune: prune)
      end

      def group(row, forms, dry:, prune:)
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
        log.compact + grants(group, name, Array(row['permissions']), forms, dry: dry, prune: prune)
      end

      # Descriptions are cosmetic, so fill in a blank one but never overwrite a
      # description someone has edited in this environment.
      def backfill_description(group, description, dry:)
        return nil if description.blank? || group.description.present?

        group.update!(description: description) unless dry
        "~ desc   #{group.group_name}"
      end

      def grants(group, name, rows, forms, dry:, prune:)
        wanted, refusals = resolve(rows, forms) { |row, key| [row['type'].to_s, key] }
        log = refusals.map { |reason, count| "! #{name}: #{reason}#{" (×#{count})" if count > 1}" }
        # A dry run against a group that does not exist yet has nothing to diff against.
        existing = group ? GroupPermission.where(group_id: group.id).to_set { |perm| [perm.permission_type, perm.permission_key] } : Set.new
        log += (wanted - existing).sort.map do |type, key|
          GroupPermission.create!(group_id: group.id, permission_type: type, permission_key: key) unless dry
          "+ grant  #{name}: #{type}/#{key}"
        end
        return log unless prune

        log + (existing - wanted).sort.map do |type, key|
          GroupPermission.where(group_id: group.id, permission_type: type, permission_key: key).delete_all unless dry
          "- grant  #{name}: #{type}/#{key}"
        end
      end

      def org(rows, forms, dry:, prune:)
        wanted, refusals = resolve(rows, forms) do |row, key|
          AclSeed.org_key(row['agency_id'], row['division_id'], row['department_id'], row['unit_id'], row['type'], key)
        end
        log = refusals.map { |reason, count| "! org    #{reason}#{" (×#{count} scopes)" if count > 1}" }
        existing = OrgPermission.all.to_set { |perm| AclSeed.org_key(perm.agency_id, perm.division_id, perm.department_id, perm.unit_id, perm.permission_type, perm.permission_key) }
        log += AclSeed.sorted(wanted - existing).map do |key|
          OrgPermission.create!(**AclSeed.org_attrs(key)) unless dry
          "+ org    #{AclSeed.org_label(key)}"
        end
        return log unless prune

        log + AclSeed.sorted(existing - wanted).map do |key|
          OrgPermission.where(**AclSeed.org_attrs(key)).delete_all unless dry
          "- org    #{AclSeed.org_label(key)}"
        end
      end

      # Rewrites each row's key for this database and drops the rows that cannot
      # be honoured here. Refusals are tallied rather than listed one by one: a
      # form missing from this database fails identically in every scope and
      # every group that grants it.
      def resolve(rows, forms)
        wanted = Set.new
        refusals = []
        rows.each do |row|
          key, refusal = FormKey.resolve(row, forms)
          refusal ? refusals << refusal : wanted << yield(row, key)
        end
        [wanted, refusals.tally]
      end
    end
  end
end
