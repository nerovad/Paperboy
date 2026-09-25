# frozen_string_literal: true

module Aim
  # The people an invoice can be handed to: everyone who works AIM. That is
  # the people on the AIM list (Aim::Member) and the AIM Admins, who are the
  # aim_admin group in ACL (one role, decided 2026-09-25: AIM Admin comes from
  # ACL, everything else from AIM's own settings). System admins reach AIM as
  # admins but have no queue unless they are on the list. Employees live in
  # GSABSS and the groups in Paperboy, so the two are joined by id here.
  module Users
    GROUPS = %w[aim_admin].freeze

    module_function

    def all
      ids = (group_employee_ids + Aim::Member.active.pluck(:employee_id)).uniq
      Employee.where(id: ids).order(:last_name, :first_name)
    end

    # The AIM Admins: members of the aim_admin group in ACL. Shown on the
    # Admin screen, so it is clear why deleting one there does not end their
    # access -- that is changed in ACL.
    def group_employee_ids
      EmployeeGroup.where(GroupID: Group.where(Group_Name: GROUPS).select(:GroupID)).pluck(:EmployeeID).uniq
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
    # (roles decided 2026-09-25): AIM Admin comes from ACL (aim_admin, or
    # system_admins), BU Admin from their BUs, and everyone else is a User.
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
