# frozen_string_literal: true

# app/services/forms/field_labels.rb

module Forms
  # column name => the label the form that collects it puts on screen.
  #
  # An audit row stores a column name, and a column name is not what anyone
  # calls the field: `impact_started` is asked as "When did the impact start?".
  # The on-screen edit trail and the audit export both need that translation,
  # so the lookup lives here rather than in either of them.
  #
  # Best-effort by design. A model with no template, or a template with no
  # field rows, yields an empty map and the caller falls back to humanizing the
  # column — a trail that cannot name a field prettily is still a trail.
  class FieldLabels
    def self.for(model_class)
      new(model_class).to_h
    end

    def initialize(model_class)
      @model_class = model_class
    end

    def to_h
      template = Forms::Template.find_by(class_name: @model_class.name)
      return {} unless template

      template.form_fields.pluck(:field_name, :label).to_h
    rescue StandardError
      {}
    end
  end
end
