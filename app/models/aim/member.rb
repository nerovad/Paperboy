# frozen_string_literal: true

module Aim
  # Someone on the AIM list: a person who works AIM. AIM Admins, the aim_admin
  # group in ACL, work AIM whether listed or not (Aim::Users.all).
  #
  # A person who leaves is deactivated, not deleted: their record and history
  # stay, they drop out of the picker and the queues, and they can come back.
  # Deleting is for mistakes.
  class Member < Record
    validates :employee_id, presence: true, uniqueness: true

    # Invoices that keep a person from being removed: the ones they own that a
    # person still has to act on. Approved and exporting ones are in the
    # worker's hands and need no owner.
    HANDS_OFF_STATES = %w[approved exporting].freeze

    scope :active, -> { where(deactivated_at: nil) }
    scope :inactive, -> { where.not(deactivated_at: nil) }

    def self.open_invoices_of(employee_id)
      Aim::Invoice.where(assigned_employee_id: employee_id)
                  .where.not(state: Aim::Invoice::TERMINAL_STATES + HANDS_OFF_STATES)
    end

    # Everyone in the aim_admin group gets a row. Safe to run again. Returns
    # how many were added.
    def self.seed_from_groups!(added_by:)
      existing = pluck(:employee_id).to_set
      missing = Aim::Users.group_employee_ids.reject { |id| existing.include?(id) }
      missing.each { |id| create!(employee_id: id, added_by: added_by) }
      missing.size
    end

    # Adds everyone in a CSV with an employee_id column (item a.1c; the Fusion
    # GSA users are docs/aim/fusion_gsa_users.csv), keeping any fusion_team and
    # fusion_roles columns for the profile's suggestions. Safe to run again:
    # people already on the list are only given the Fusion details. Returns
    # [added, kept, unknown], the last being ids with no GSABSS employee.
    def self.import_csv!(path, added_by:)
      rows = CSV.read(path, headers: true).filter_map do |row|
        id = row['employee_id'].to_s[/\A\d+\z/]&.to_i
        [id, row['fusion_team'].presence, row['fusion_roles'].presence] if id
      end.uniq(&:first)
      known = Employee.where(id: rows.map(&:first)).pluck(:id).to_set
      existing = where(employee_id: rows.map(&:first)).pluck(:employee_id).to_set
      rows.select { |id, *| known.include?(id) }.each do |id, team, roles|
        member = find_or_initialize_by(employee_id: id)
        member.added_by ||= added_by
        member.update!(fusion_team: team, fusion_roles: roles)
      end
      [(known - existing).size, existing.size, rows.map(&:first).reject { |id| known.include?(id) }]
    end

    # { "GSA Maintenance" => ["4703"], ... }: the BU most of each Fusion team's
    # people are in, read from GSABSS. Ties give every tied BU.
    def self.fusion_team_units
      members = where.not(fusion_team: nil).pluck(:employee_id, :fusion_team)
      units = Employee.where(id: members.map(&:first)).pluck(:id, :unit).to_h
      members.group_by(&:last).transform_values do |pairs|
        counts = pairs.filter_map { |id, _| units[id].presence }.tally
        top = counts.values.max
        counts.select { |_, count| count == top }.keys.sort
      end
    end

    def employee
      @employee ||= Employee.find_by(id: employee_id)
    end

    def open_invoices = self.class.open_invoices_of(employee_id)

    def active? = deactivated_at.nil?

    def deactivate!(by:, reason:)
      update!(deactivated_at: Time.current, deactivated_by: by, deactivation_reason: reason.to_s.squish.presence)
    end

    def reactivate!
      update!(deactivated_at: nil, deactivated_by: nil, deactivation_reason: nil)
    end

    def fusion_role_list = fusion_roles.to_s.split(';').map(&:strip)

    # The BUs this person supervised in Fusion: each supervised team's BU.
    def fusion_supervised_units(team_units = self.class.fusion_team_units)
      fusion_role_list.filter_map { |role| role.delete_prefix('supervises ') if role.start_with?('supervises ') }
                      .flat_map { |team| team_units.fetch(team, []) }.uniq
    end

    # Fusion's roles made real, once, at go-live (Joshua, 2026-09-25: applied,
    # then reviewed on the profiles, rather than offered as suggestions). A
    # Fusion supervisor becomes BU Admin of their team's BU; a BU Admin already
    # set is left alone. Fusion app admins cannot be made AIM Admins here -- that
    # is the aim_admin group in ACL -- so they are returned to be listed.
    # Returns [[employee_id, unit], ...] made, and the app admins' employee ids.
    def self.apply_fusion_roles!(granted_by:)
      team_units = fusion_team_units
      made = []
      where.not(fusion_roles: nil).find_each do |member|
        member.fusion_supervised_units(team_units).each do |unit|
          row = Aim::UserBudgetUnit.find_or_initialize_by(employee_id: member.employee_id, budget_unit: unit)
          next if row.bu_admin

          row.update!(bu_admin: true, hidden: false, granted_by: granted_by)
          made << [member.employee_id, unit]
        end
      end
      app_admins = where.not(fusion_roles: nil).select { |m| m.fusion_role_list.include?('app admin') }.map(&:employee_id)
      [made, app_admins]
    end
  end
end
