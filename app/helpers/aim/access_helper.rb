# frozen_string_literal: true

module Aim
  # Who may see what in Automated Invoice Management.
  #
  # These were private methods on Aim::BaseController, exposed to its own views
  # with helper_method. The command palette asks the same questions from every
  # other app — where no AIM controller is running — so they are a helper now
  # and the base controller reaches them through +helpers+ like everything else.
  #
  # Admin / Approver mode (item a.2): an AIM Admin or Staff member can switch
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

    # Who manages AIM's people: aim_admin and system admins, not aim_staff
    # (decided 2026-09-25). Staff work every invoice; admins decide who works.
    def aim_user_admin?
      (current_user_group_names & %w[system_admins aim_admin]).any? && !aim_approver_mode?
    end

    # Who sees the Pipeline, Vendors and the Dashboard, and works every BU:
    # AIM Admins and AIM Staff, by group (roles decided 2026-09-25). The
    # Processing Queues and Dashboard features under ACL no longer grant this:
    # they had been given to whole departments at org level, which made every
    # User there staff. Capabilities return deliberately in step a.6.
    def aim_queue_access?
      aim_real_queue_access? && !aim_approver_mode?
    end

    # The budget units whose shared queues this person may move an invoice to:
    # Staff and Admins any (nil), everyone else the BUs they cover.
    def aim_move_units
      return nil if aim_queue_access?

      Aim::Users.shared_budget_units(aim_session_employee_id, staff: false)
    end

    # [label, unit] choices for the Move dialog's "another budget unit".
    def aim_move_unit_options
      allowed = aim_move_units
      options = Aim::UserBudgetUnit.unit_options
      allowed.nil? ? options : options.select { |_, unit| allowed.include?(unit) }
    rescue ActiveRecord::ActiveRecordError
      []
    end

    def aim_real_admin?
      (current_user_group_names & %w[system_admins aim_admin aim_staff]).any?
    end

    def aim_real_queue_access? = aim_real_admin?

    # Only someone with more than a User's reach has a mode to switch.
    def aim_approver_mode?
      aim_real_queue_access? && aim_mode == 'approver'
    end

    def aim_mode
      session[:aim_mode] ||= Aim::UserPreference.start_mode_for(aim_session_employee_id)
    end

    def aim_session_employee_id
      (session[:user] || session['user'] || {})['employee_id']
    end
  end
end
