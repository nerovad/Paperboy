# frozen_string_literal: true

module Aim
  # The people an invoice can be handed to: everyone who can work the AIM
  # queues. That is the people added on the Admin screen (Aim::Member) and,
  # until the switchover ends, the aim_admin, aim_staff and system_admins
  # groups, which predate the ACL section, plus every group granted AIM's
  # Processing Queues feature under ACL. Employees live in GSABSS and the
  # groups in Paperboy, so the two are joined by id here rather than in SQL.
  module Users
    GROUPS = %w[system_admins aim_admin aim_staff].freeze
    FEATURE = AppFeature.permission_key('aim', 'processing_queues')

    module_function

    def all
      ids = (group_employee_ids + Aim::Member.pluck(:employee_id)).uniq
      Employee.where(id: ids).order(:last_name, :first_name)
    end

    # The people who are AIM users through a group rather than the Admin
    # screen. Shown on the Admin screen during the switchover, so it is clear
    # why removing someone there does not end their access.
    def group_employee_ids
      group_ids = Group.where(Group_Name: GROUPS).pluck(:GroupID) +
                  GroupPermission.where(Permission_Key: FEATURE).pluck(:GroupID)
      EmployeeGroup.where(GroupID: group_ids.uniq).pluck(:EmployeeID).uniq
    end

    # Whether this employee has a queue: is one of the people who work AIM.
    def member?(employee_id)
      employee_id.present? && all.exists?(id: employee_id)
    rescue ActiveRecord::ActiveRecordError
      false
    end

    # The budget units whose shared queues this person works: their own unit
    # from GSABSS, unless hidden, plus the BUs granted on their profile (a.2). AIM staff
    # see every BU (nil means all). The one place the rule lives.
    def shared_budget_units(employee_id, staff:)
      return nil if staff
      return [] if employee_id.blank?

      home = Employee.where(id: employee_id).pick(:unit).presence
      rows = Aim::UserBudgetUnit.for_person(employee_id).pluck(:budget_unit, :hidden)
      hidden = rows.select(&:last).map(&:first)
      ([home] + rows.map(&:first)).compact.uniq - hidden
    rescue ActiveRecord::ActiveRecordError
      []
    end

    # What a person is in AIM, for their profile and the Users & Queues list
    # (roles decided 2026-09-25): AIM Admin and AIM Staff come from the groups,
    # BU Admin from their BUs, and everyone on the list is a User.
    def roles_of(employee_id) = roles_by_person([employee_id]).fetch(employee_id.to_i)

    # The same for many people at once: { employee_id => [roles] }.
    def roles_by_person(employee_ids)
      ids = employee_ids.map(&:to_i)
      names = Group.pluck(:GroupID, :Group_Name).to_h { |id, name| [id, name.to_s.downcase] }
      groups = EmployeeGroup.where(EmployeeID: ids).pluck(:EmployeeID, :GroupID)
                            .group_by(&:first).transform_values { |pairs| pairs.map { |_, id| names[id] } }
      admins = Aim::UserBudgetUnit.where(employee_id: ids).administered.distinct.pluck(:employee_id).to_set
      ids.index_with { |id| role_names(groups.fetch(id, []), admins.include?(id)) }
    rescue ActiveRecord::ActiveRecordError
      ids.index_with { ['User'] }
    end

    def role_names(groups, bu_admin)
      roles = []
      roles << 'AIM Admin' if groups.intersect?(%w[system_admins aim_admin])
      roles << 'AIM Staff' if groups.include?('aim_staff')
      roles << 'BU Admin' if bu_admin
      roles.presence || ['User']
    end

    # The BUs this person is BU Admin of.
    def administered_budget_units(employee_id)
      return [] if employee_id.blank?

      Aim::UserBudgetUnit.for_person(employee_id).administered.pluck(:budget_unit)
    rescue ActiveRecord::ActiveRecordError
      []
    end

    # Display names, as a queue is named after a person: "First Last".
    def names
      all.map { |employee| "#{employee.first_name} #{employee.last_name}".squish }.compact_blank.uniq
    rescue ActiveRecord::ActiveRecordError => e
      Rails.logger.warn "AIM could not list its users: #{e.message}"
      []
    end
  end
end
