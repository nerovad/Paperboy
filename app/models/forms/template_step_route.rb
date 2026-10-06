# frozen_string_literal: true

module Forms
  # One of the routes a 'multiple' routing step fans out to: a target and the
  # label its task carries while it is open ("Waiting on Vendor Approval").
  class TemplateStepRoute < ApplicationRecord
    self.table_name = 'form_template_step_routes'

    belongs_to :routing_step, class_name: 'Forms::TemplateRoutingStep',
                              foreign_key: :form_template_routing_step_id, inverse_of: :routes

    include Forms::RouteTarget

    # What a route carries besides its place in the list. Shared by everything
    # that copies routes about: the builder, the duplicator and the form seed.
    COLUMNS = %w[routing_type employee_id group_id org_filter_level authorization_service_type label].freeze

    validates :routing_type, presence: true, inclusion: { in: TARGET_TYPES }

    def default_label
      "Sent to #{target_label}"
    end

    # The label the task shows while it is open.
    def task_label
      label.presence || default_label
    end
  end
end
