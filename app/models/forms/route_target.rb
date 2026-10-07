# frozen_string_literal: true

module Forms
  # Somewhere a submission can be routed to: the submitter's supervisor, one
  # employee, a group, or whoever holds an authorization. Three records name
  # such a target in the same five columns -- a routing step, one route of a
  # multi-route step, and the task a submission carries for that route -- and
  # this is the one place that resolves those columns to people.
  module RouteTarget
    extend ActiveSupport::Concern

    TARGET_TYPES = %w[supervisor employee group authorization].freeze
    ORG_FILTER_LEVELS = %w[agency division department unit].freeze
    ORG_FILTER_LABELS = {
      'agency' => 'Agency',
      'division' => 'Division',
      'department' => 'Department',
      'unit' => 'Unit'
    }.freeze

    included do
      validates :employee_id, presence: true, if: :routes_to_employee?
      validates :group_id, presence: true, if: :routes_to_group?
      validates :authorization_service_type, presence: true,
                                             inclusion: { in: ->(_target) { AuthorizationConsole.routing_keys } },
                                             if: :routes_to_authorization?
      validates :org_filter_level, inclusion: { in: ORG_FILTER_LEVELS }, allow_blank: true
      validate :org_filter_only_for_group_routing
    end

    def routes_to_employee?
      routing_type == 'employee'
    end

    def routes_to_group?
      routing_type == 'group'
    end

    def routes_to_authorization?
      routing_type == 'authorization'
    end

    # Whether the columns this routing type needs are filled in.
    def valid_target?
      case routing_type
      when 'supervisor' then true
      when 'employee' then employee_id.present?
      when 'group' then group_id.present?
      when 'authorization' then AuthorizationConsole.routing_keys.include?(authorization_service_type)
      else false
      end
    end

    # A group or authorization target is a queue: nobody is named, everyone
    # eligible sees the work and the first to act takes it.
    def pool?
      routes_to_group? || routes_to_authorization?
    end

    # Human label for the chosen authorization option (e.g. "Parking Permits",
    # "HCA Safety Officer"), resolved through the console registry.
    def authorization_service_type_label
      AuthorizationConsole.routing_label(authorization_service_type)
    end

    def target_label
      case routing_type
      when 'supervisor'
        'Supervisor'
      when 'employee'
        employee_name || "Employee ##{employee_id}"
      when 'group'
        base = group_name || "Group ##{group_id}"
        org_filtered? ? "#{base} (submitter's #{org_filter_label})" : base
      when 'authorization'
        "Authorized approver — #{authorization_service_type_label}"
      end
    end

    # True when this is a group target narrowed to members who share the
    # submitter's value at the configured org level.
    def org_filtered?
      routes_to_group? && org_filter_level.present?
    end

    def org_filter_label
      ORG_FILTER_LABELS[org_filter_level]
    end

    def employee_name
      return nil unless employee_id

      employee = Employee.find_by(employee_id: employee_id)
      employee&.full_name
    rescue StandardError
      nil
    end

    def group_name
      return nil unless group_id

      Group.find_by(GroupID: group_id)&.group_name
    rescue StandardError
      nil
    end

    # The one person this target names for `submission`, or nil for a pool.
    # Work aimed at somebody who is out goes to whoever is covering for them,
    # so it never lands in an inbox nobody is reading. A pool is left alone:
    # the rest of the group is already the cover.
    def assignee_id_for(submission)
      assignee = case routing_type
                 when 'supervisor' then target_submitter(submission)&.supervisor_id&.to_s
                 when 'employee' then employee_id.to_s
                 end

      AwayPeriod.assignee_for(assignee).presence
    end

    # The concrete employee_ids this target resolves to for `submission`.
    def target_approver_ids(submission)
      case routing_type
      when 'supervisor', 'employee'
        [assignee_id_for(submission)].compact
      when 'group'
        group_eligible_ids(submission)
      when 'authorization'
        authorization_eligible_ids(submission)
      else
        []
      end
    rescue StandardError
      []
    end

    private

    def target_submitter(submission)
      eid = submission.respond_to?(:employee_id) ? submission.employee_id : nil
      # Employee or Contractor — both expose supervisor_id/unit for routing.
      eid.present? ? Submitter.resolve(eid) : nil
    end

    # Group members, narrowed to those sharing the submitter's value at the
    # configured org level when org filtering is on.
    def group_eligible_ids(submission)
      return [] unless group_id

      member_ids = EmployeeGroup.member_ids(group_id).map(&:to_s)
      return member_ids unless org_filtered?

      submitter_value = (submission.public_send(org_filter_level) if submission.respond_to?(org_filter_level))
      return [] if submitter_value.blank?

      members = Employee.where(id: member_ids).to_a
      org_values = member_org_values(members)
      members.select { |e| org_values[e.unit.to_s].to_s == submitter_value.to_s }.map { |e| e.id.to_s }
    end

    # Each member's unit mapped to its value at the configured org level: the
    # unit itself, or the agency, division or department that unit sits in.
    def member_org_values(members)
      unit_ids = members.map(&:unit).compact.uniq
      return unit_ids.to_h { |unit| [unit.to_s, unit] } if org_filter_level == 'unit'
      return {} if unit_ids.empty?

      Coa::Unit.where(unit_id: unit_ids).to_h do |unit|
        [unit.unit_id.to_s, unit.public_send("#{org_filter_level}_id")]
      end
    end

    # Everyone holding this authorization over the submission. Each console in
    # the registry scopes it its own way — AuthorizedApprover by budget unit,
    # Safety Reporting by HCA org node.
    def authorization_eligible_ids(submission)
      return [] if authorization_service_type.blank?

      AuthorizationConsole.approver_ids_for(authorization_service_type, submission)
    end

    def org_filter_only_for_group_routing
      return if org_filter_level.blank?
      return if routes_to_group?

      errors.add(:org_filter_level, 'is only valid for group routing steps')
    end
  end
end
