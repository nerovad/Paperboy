# frozen_string_literal: true

module Forms
  # A value a routing step's "Only run this step if" condition can test that
  # isn't a form-builder field -- usually because a hand-built form keeps it in
  # custom markup (the parking form's per-vehicle permit types). A form model
  # offers these from `self.routing_condition_fields` and answers each by a
  # public method named `field_name`. When that method returns an array, the
  # condition asks whether the value is in it.
  RoutingConditionField = Data.define(:field_name, :label, :field_type, :dropdown_values) do
    def initialize(field_name:, label:, field_type: 'text', dropdown_values: [])
      super
    end
  end
end
