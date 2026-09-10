# frozen_string_literal: true

# app/services/forms/audit_columns.rb

module Forms
  # How the columns every audit row shares are rendered, across one set of form
  # models: the reference somebody would search for, the form's own name, the
  # label its form puts on a column, and the readable form of a stored value.
  #
  # Held apart from Forms::AuditExport because all of this is per-model lookup
  # with a cache in front: a template name, a field label map, an AuditValue,
  # and every one of those is shared by all three audit tables. The export
  # itself is then only three queries and the shape of their rows.
  #
  # Only models handed to the constructor can be asked about. That is the point:
  # the export scopes its queries to the same list, so a row whose polymorphic
  # type is not in it is a row the caller was never allowed to see.
  class AuditColumns
    TIMESTAMP = '%Y-%m-%d %H:%M:%S'

    def initialize(model_classes)
      @models = Array(model_classes).compact.index_by(&:name)
    end

    def class_names
      @models.keys
    end

    def reference(class_name, record_id)
      "#{Forms::Reference.prefix_for(@models.fetch(class_name), prefix_map)}-#{record_id}"
    end

    def form_name(class_name)
      template_names[class_name].presence || class_name.underscore.humanize
    end

    def label(class_name, column)
      field_labels[class_name][column].presence || column.humanize
    end

    def value(class_name, column, raw)
      audit_values[class_name].call(column, raw)
    end

    def at(time)
      time&.in_time_zone&.strftime(TIMESTAMP)
    end

    # One GSABSS round trip for everybody named across a batch of rows.
    # Best-effort like every other cross-database lookup in an audit trail: an
    # id that no longer resolves is left to stand on its own in the ID column.
    def employee_names(ids)
      ids = ids.map(&:to_s).compact_blank.uniq
      return {} if ids.empty?

      Employee.where(id: ids).to_a.to_h do |employee|
        [employee.id.to_s, [employee.first_name, employee.last_name].compact_blank.join(' ')]
      end
    rescue StandardError
      {}
    end

    private

    def prefix_map
      @prefix_map ||= Forms::Reference.prefix_map
    end

    def template_names
      @template_names ||= Forms::Template.where(class_name: class_names).pluck(:class_name, :name).to_h
    end

    def field_labels
      @field_labels ||= Hash.new { |cache, name| cache[name] = Forms::FieldLabels.for(@models.fetch(name)) }
    end

    def audit_values
      @audit_values ||= Hash.new { |cache, name| cache[name] = Forms::AuditValue.new(model: @models.fetch(name)) }
    end
  end
end
