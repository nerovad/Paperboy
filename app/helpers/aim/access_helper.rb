# frozen_string_literal: true

module Aim
  # Who may see what in Automated Invoice Management.
  #
  # These were private methods on Aim::BaseController, exposed to its own views
  # with helper_method. The command palette asks the same questions from every
  # other app — where no AIM controller is running — so they are a helper now
  # and the base controller reaches them through +helpers+ like everything else.
  #
  # Admin / Approver mode (item a.2): an AIM Admin can switch
  # to Approver mode, in which every check below answers as it would for a
  # User. The switch is in the session; the mode they start in is theirs to
  # set (Aim::UserPreference). The aim_real_* checks ignore the mode, for the
  # switch itself.
  module AccessHelper
    def aim_admin?
      aim_real_admin? && !aim_approver_mode?
    end

    # Whether the signed-in person has a queue of their own: AIM staff, or one
    # of the people who work AIM. Everyone else sees only Upload. Approver mode
    # keeps an admin's queue: approving is what the mode is for.
    def aim_has_queue?
      return true if aim_real_queue_access?

      Aim::Users.member?(aim_session_employee_id)
    end

    # Who works the Fiscal stage (item f): the people an AIM Admin has marked
    # Fiscal on their profile, and the AIM Admins themselves.
    def aim_fiscal?
      return true if aim_queue_access?
      return @aim_fiscal unless @aim_fiscal.nil?

      id = aim_session_employee_id
      @aim_fiscal = id.present? && Aim::Member.active.exists?(employee_id: id, fiscal: true)
    rescue ActiveRecord::ActiveRecordError
      false
    end

    # Who manages AIM's people. One role since 2026-09-25: the AIM Admins,
    # who also process invoices, so this is aim_queue_access? by another name.
    def aim_user_admin? = aim_queue_access?

    # Who sees the Pipeline, Vendors and the Dashboard, and works every BU:
    # the AIM Admins, the aim_admin group in ACL (plus system admins, who
    # reach everything in Paperboy). One role, decided 2026-09-25. The
    # Processing Queues and Dashboard features under ACL no longer grant this:
    # they had been given to whole departments at org level, which made every
    # User there staff. Capabilities return deliberately in step a.6.
    def aim_queue_access?
      aim_real_queue_access? && !aim_approver_mode?
    end

    # The budget units this person oversees on the BU page: every one (nil)
    # for AIM Admins, the ones they are BU Admin of otherwise, and
    # none in Approver mode, which hides admin tools of every kind.
    def aim_bu_admin_units
      return [] if aim_approver_mode?
      return nil if aim_queue_access?

      @aim_bu_admin_units ||= Aim::Users.administered_budget_units(aim_session_employee_id)
    end

    # The budget units whose people this person manages: every one (nil) for
    # AIM Admins, the ones they are BU Admin of otherwise; none in Approver
    # mode.
    def aim_managed_units
      return [] if aim_approver_mode?
      return nil if aim_user_admin?

      @aim_managed_units ||= Aim::Users.administered_budget_units(aim_session_employee_id)
    end

    # Every BU this person works is one the current user manages: what a BU
    # Admin needs before deactivating someone.
    def aim_manages_all_units_of?(employee_id)
      units = aim_managed_units
      return true if units.nil?

      theirs = Aim::Users.budget_units_of(employee_id)
      theirs.any? && (theirs - units).empty?
    end

    def aim_manages_people?
      units = aim_managed_units
      units.nil? || units.any?
    end

    def aim_bu_page?
      units = aim_bu_admin_units
      units.nil? || units.any?
    end

    # The budget units whose shared queues this person may move an invoice to:
    # AIM Admins any (nil), everyone else the BUs they work in.
    def aim_move_units
      return nil if aim_queue_access?

      Aim::Users.budget_units_of(aim_session_employee_id)
    end

    # The people an invoice can go to, grouped by the BUs they work in:
    # [[unit, "4641 · Document Management", [["Gannon, Joshua (126566)", 126566], ...]], ...]
    # in BU order, anyone with no BU last. Someone in several BUs is under each.
    # For the grouped person picker (aim_grouped_search_controller).
    def aim_person_groups
      people = Aim::Users.all.pluck(:id, :first_name, :last_name, :agency, :unit)
      names = people.to_h { |id, first, last, _, _| [id, Employee.format_picker_label(id, first, last)] }
      grants = Aim::UserBudgetUnit.where(employee_id: names.keys).pluck(:employee_id, :budget_unit, :hidden)
      by_unit = aim_people_by_unit(people.map { |id, _, _, agency, unit| [id, agency, unit] }, grants)
      coa = Aim::Units.new
      groups = by_unit.keys.sort.map { |unit| [unit, coa.label(unit), aim_named(by_unit[unit], names)] }
      loose = names.keys - by_unit.values.flatten
      loose.any? ? groups + [[nil, 'No budget unit', aim_named(loose, names)]] : groups
    rescue ActiveRecord::ActiveRecordError
      []
    end

    def aim_named(ids, names) = ids.sort_by { |id| names[id].downcase }.map { |id| [names[id], id] }

    # The BUs each AIM user works in, as { unit => [employee_id, ...] }: their
    # home unit unless hidden there, plus every BU granted on their profile
    # and not hidden. The same rule as Aim::Users.budget_units_of, for
    # everyone at once, from rows the caller has already read:
    #   people  [[employee_id, home_unit], ...]
    #   grants  [[employee_id, budget_unit, hidden], ...]  (Aim::UserBudgetUnit)
    # The grouped person picker and the BU page both list people this way.
    # people are [employee_id, agency, raw unit]; the home unit is resolved as
    # Aim::Users.home_unit does, so an HCA sub-unit counts as its parent.
    def aim_people_by_unit(people, grants)
      hidden = grants.select(&:last).to_set { |grant| grant.first(2) }
      homes = Aim::Users.home_units(people.to_h { |id, agency, unit| [id, [agency, unit]] })
      by_unit = Hash.new { |hash, unit| hash[unit] = [] }
      homes.each { |id, unit| by_unit[unit] << id if unit.present? && !hidden.include?([id, unit]) }
      grants.reject(&:last).each { |id, unit, _| by_unit[unit] << id }
      by_unit.transform_values(&:uniq)
    end

    # The Move dialog's "another budget unit" choices, grouped by agency, from
    # the Chart of Accounts.
    def aim_move_unit_options
      Aim::Units.new.grouped_options(only: aim_move_units)
    rescue ActiveRecord::ActiveRecordError
      []
    end

    def aim_real_admin?
      (current_user_group_names & %w[system_admins aim_admin]).any?
    end

    def aim_real_queue_access? = aim_real_admin?

    # Only someone with more than a User's reach has a mode to switch.
    def aim_approver_mode?
      aim_real_queue_access? && aim_mode == 'approver'
    end

    def aim_mode
      session[:aim_mode] ||= Aim::UserPreference.start_mode_for(aim_session_employee_id)
    end

    def aim_session_employee_id = current_user&.employee_id
  end
end
