# frozen_string_literal: true

module Aim
  # Who may see what in Automated Invoice Management.
  #
  # These were private methods on Aim::BaseController, exposed to its own views
  # with helper_method. The command palette asks the same questions from every
  # other app — where no AIM controller is running — so they are a helper now
  # and the base controller reaches them through +helpers+ like everything else.
  module AccessHelper
    def aim_admin?
      (current_user_group_names & %w[system_admins aim_admin aim_staff]).any?
    end

    # Who sees the Processing Queues section of the sidebar, and the screens
    # behind it. The aim_admin/aim_staff groups predate the ACL section and
    # keep working; the grant under ACL > Application Features is the way to
    # hand out queue access without adding someone to those groups.
    # Whether the signed-in person has a queue of their own: AIM staff, or one
    # of the people who work AIM. Everyone else sees only Upload.
    def aim_has_queue?
      return true if aim_queue_access?

      employee_id = (session[:user] || session['user'] || {})['employee_id']
      Aim::Users.member?(employee_id)
    end

    def aim_queue_access?
      aim_admin? || can_use_app_feature?('aim', 'processing_queues')
    end
  end
end
