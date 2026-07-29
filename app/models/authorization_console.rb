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
# Each console also declares how the form builder can route to it: the options
# offered in a routing step's authorization dropdown, and how to turn a chosen
# option into the employees eligible to act on a submission. Routing keys are
# stored verbatim in form_template_routing_steps.authorization_service_type —
# the AuthorizedApprover service codes ("P", "E", "V", "C", "K") are the
# original vocabulary and keep working unchanged.
#
# Adding a console means adding a Definition here — the picker, the switcher,
# the access checks and the builder's routing dropdown all read from this list.
class AuthorizationConsole
  Definition = Struct.new(:key, :label, :form_class_name, :route_name,
                          :routing_group_label, :routing_options,
                          :approver_resolver, :holder_counter, :inbox_filter,
                          keyword_init: true) do
    # The FormTemplate this console authorizes for. Used for the picker label
    # fallback and to tie a console to the form's ACL entry.
    def form_template
      FormTemplate.find_by(class_name: form_class_name)
    end

    def form_template_id
      form_template&.id
    end

    # [[option label, routing key], ...] — the pair order select helpers want.
    def routing_choices
      routing_options.respond_to?(:call) ? routing_options.call : Array(routing_options)
    end

    def routing_key?(routing_key)
      routing_choices.any? { |(_label, key)| key.to_s == routing_key.to_s }
    end

    # Employee ids eligible to act on `submission` under this routing key.
    def approver_ids(routing_key, submission)
      approver_resolver.call(routing_key, submission)
    end

    # How many people currently hold this authorization at all, ignoring org
    # scope. Drives the builder's "may route to no one" heads-up.
    def holder_count(routing_key)
      holder_counter.call(routing_key)
    end

    # Column => values narrowing submissions at this step to the ones the given
    # employees are authorized over, or nil when they hold nothing. The inbox
    # can't reuse approver_ids: it filters submissions in SQL rather than
    # resolving approvers one submission at a time.
    def inbox_conditions(routing_key, employee_ids)
      inbox_filter.call(routing_key, employee_ids)
    end
  end

  # Parking permits, employee/volunteer/vendor badges and facility keys. Backed
  # by AuthorizedApprover and scoped by department + budget unit + building.
  SERVICES = Definition.new(
    key: 'services',
    label: 'Parking, Badges & Keys Authorizations',
    form_class_name: 'ParkingLotSubmission',
    route_name: :authorization_console_index_path,
    routing_group_label: 'Parking, Badges & Keys',
    routing_options: -> { AuthorizedApprover::SERVICE_TYPES.map { |code, label| [label, code] } },
    approver_resolver: lambda { |routing_key, submission|
      next [] unless submission.respond_to?(:unit) && submission.unit.present?

      AuthorizedApprover.approver_ids_covering_unit(
        service_type: routing_key,
        unit_id: submission.unit
      )
    },
    holder_counter: ->(routing_key) { AuthorizedApprover.where(service_type: routing_key).count },
    inbox_filter: lambda { |routing_key, employee_ids|
      AuthorizedApprover.inbox_conditions_for(service_type: routing_key, employee_ids: employee_ids)
    }
  )

  # Safety Reporting. Backed by SafetyReportAuthorization — just the safety
  # officer covering each HCA org node.
  HCA_SAFETY = Definition.new(
    key: 'hca_safety',
    label: 'HCA Safety Reporting Authorizations',
    form_class_name: 'SafetyReport',
    route_name: :safety_authorizations_path,
    routing_group_label: 'HCA Safety Reporting',
    routing_options: -> { [['HCA Safety Officer', 'hca_safety']] },
    approver_resolver: ->(_routing_key, submission) { SafetyReportAuthorization.officer_ids_for_submission(submission) },
    holder_counter: ->(_routing_key) { SafetyReportAuthorization.count },
    inbox_filter: ->(_routing_key, employee_ids) { SafetyReportAuthorization.inbox_conditions_for(employee_ids) }
  )

  ALL = [SERVICES, HCA_SAFETY].freeze

  def self.find(key)
    ALL.find { |console| console.key == key.to_s }
  end

  # Grouped choices for the builder's authorization dropdown, in the shape
  # grouped_options_for_select expects.
  def self.routing_option_groups
    ALL.filter_map do |console|
      choices = console.routing_choices
      [console.routing_group_label, choices] if choices.any?
    end
  end

  # Every valid value for a routing step's authorization_service_type.
  def self.routing_keys
    ALL.flat_map { |console| console.routing_choices.map(&:last) }
  end

  def self.console_for_routing_key(routing_key)
    return nil if routing_key.blank?

    ALL.find { |console| console.routing_key?(routing_key) }
  end

  # Human label for a routing key, falling back to the key itself so a value
  # left over from a removed console still renders.
  def self.routing_label(routing_key)
    console = console_for_routing_key(routing_key)
    return routing_key if console.nil?

    console.routing_choices.find { |(_label, key)| key.to_s == routing_key.to_s }&.first || routing_key
  end

  def self.approver_ids_for(routing_key, submission)
    console = console_for_routing_key(routing_key)
    return [] if console.nil?

    Array(console.approver_ids(routing_key.to_s, submission)).map(&:to_s)
  rescue StandardError
    []
  end

  # Column => values the inbox can filter submissions by for this routing key,
  # or nil when these employees hold nothing under it.
  def self.inbox_conditions_for(routing_key, employee_ids)
    console = console_for_routing_key(routing_key)
    return nil if console.nil?

    console.inbox_conditions(routing_key.to_s, Array(employee_ids))
  rescue StandardError
    nil
  end

  # False when nobody holds the authorization behind this routing key.
  def self.holders?(routing_key)
    console = console_for_routing_key(routing_key)
    return false if console.nil?

    console.holder_count(routing_key.to_s).positive?
  rescue StandardError
    true # never block a save on a failed pre-check
  end
end
