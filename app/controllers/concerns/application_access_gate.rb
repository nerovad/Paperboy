# frozen_string_literal: true

# The one application gate. Each namespace base controller calls
# +.gate_application+ with its ACL key and the name in the refusal.
#
# The sidebar only hides an app someone cannot reach. This is what stops them
# typing the URL. Access is an ACL > Applications grant; system admins bypass
# it inside +can_access_app?+. A global (all-org-nil) grant applies to
# everyone, so a signed-out visitor is refused here too, not left to the
# sign-in filter alone.
#
# Data Runner's index is its own sign-in panel. That app passes
# +when_signed_out: :continue+, and a signed-out visitor falls through. A
# signed-in visitor without the grant is still refused.
module ApplicationAccessGate
  extend ActiveSupport::Concern

  Gate = Data.define(:key, :label, :when_signed_out)

  included do
    class_attribute :application_access_gate, instance_accessor: false
  end

  class_methods do
    def gate_application(key, label:, when_signed_out: :refuse)
      raise ArgumentError, "when_signed_out must be :refuse or :continue (got #{when_signed_out.inspect})" unless %i[refuse continue].include?(when_signed_out)

      self.application_access_gate = Gate.new(key: key, label: label, when_signed_out: when_signed_out)
      before_action :require_app_access
    end
  end

  private

  def require_app_access
    gate = self.class.application_access_gate
    return if gate.when_signed_out == :continue && current_user.blank?
    return if current_user.present? && helpers.can_access_app?(gate.key)

    redirect_to root_path, alert: "You do not have access to #{gate.label}."
  end
end
