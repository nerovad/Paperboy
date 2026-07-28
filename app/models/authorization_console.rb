# frozen_string_literal: true

# app/models/authorization_console.rb
#
# Registry of the authorization consoles the app knows how to render.
#
# The console started life as a single screen for the GSA services (parking
# permits, badges, facility keys) backed by AuthorizedApprover. Other forms now
# need their own authorization lists, so the screen opens on a form picker and
# each entry here supplies the label, the form it belongs to (for ACL) and the
# route that renders it.
#
# Adding a console means adding a Definition here — the picker, the switcher and
# the access checks all read from this list.
class AuthorizationConsole
  Definition = Struct.new(:key, :label, :form_class_name, :route_name, keyword_init: true) do
    # The FormTemplate this console authorizes for. Used for the picker label
    # fallback and to tie a console to the form's ACL entry.
    def form_template
      FormTemplate.find_by(class_name: form_class_name)
    end

    def form_template_id
      form_template&.id
    end
  end

  # Parking permits, employee/volunteer/vendor badges and facility keys. Backed
  # by AuthorizedApprover and scoped by department + budget unit + building.
  SERVICES = Definition.new(
    key: 'services',
    label: 'Parking, Badges & Keys Authorizations',
    form_class_name: 'ParkingLotSubmission',
    route_name: :authorization_console_index_path
  )

  # Safety Reporting. Backed by SafetyReportAuthorization — just the safety
  # officer covering each HCA org node.
  HCA_SAFETY = Definition.new(
    key: 'hca_safety',
    label: 'HCA Safety Reporting Authorizations',
    form_class_name: 'SafetyReport',
    route_name: :safety_authorizations_path
  )

  ALL = [SERVICES, HCA_SAFETY].freeze

  def self.find(key)
    ALL.find { |console| console.key == key.to_s }
  end
end
