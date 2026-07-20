# frozen_string_literal: true

# A Records table whose rows are a form's submissions and whose columns are the
# form's own fields — the "show form data like Airtable" case. Unlike the
# model-backed RegistryTable, nothing is declared in code: columns are derived
# from the form's FormField definitions, so any form an admin flags
# (form_templates.records_table) becomes a grid automatically.
#
# Duck-types the RegistryTable interface (slug/label/page_key/columns/scope/…)
# so it plugs into the generic grid, the landing, and the column customizer
# unchanged. Columns are named by their reader method, so the customizer's
# generic `row.public_send(name)` extractor needs no special-casing.
class FormBackedTable
  # Field types that carry no persisted value to show as a column.
  NON_DISPLAY_FIELD_TYPES = %w[media_attachment information].freeze
  SLUG_PREFIX = 'form-'

  class << self
    # All flagged form-backed tables, skipping any whose model can't be loaded.
    def all
      return [] unless enabled?

      FormTemplate.where(records_table: true).includes(:form_fields).order(:name).filter_map do |template|
        new(template) if resolvable?(template)
      end
    end

    def find(slug)
      slug = slug.to_s
      return nil unless slug.start_with?(SLUG_PREFIX)

      id = slug.delete_prefix(SLUG_PREFIX)
      return nil unless id.match?(/\A\d+\z/)

      template = FormTemplate.find_by(id: id, records_table: true)
      template && resolvable?(template) ? new(template) : nil
    end

    private

    # Guard so lookups don't blow up before the opt-in column migration lands.
    def enabled?
      FormTemplate.column_names.include?('records_table')
    end

    def resolvable?(template)
      template.class_name.safe_constantize.respond_to?(:column_names)
    end
  end

  attr_reader :template

  def initialize(template)
    @template = template
  end

  def model
    @model ||= template.class_name.constantize
  end

  def slug = "#{SLUG_PREFIX}#{template.id}"
  def label = template.name
  def page_key = "records:#{slug}"

  # Admin-only for now (no group/dropdown grant); served by the generic grid.
  def permission = nil
  def dropdown_key = nil
  def route = nil

  def count = model.count
  def scope = model.all

  # Derived columns: an ID, each visible form field (in form order), an optional
  # status badge, and the created timestamp.
  def columns
    [id_column, *field_columns, *status_column, created_column]
  end

  private

  def id_column
    Registry::Column.new(name: 'id', label: 'ID', kind: :text, filter_kind: nil, sortable: true)
  end

  def created_column
    Registry::Column.new(name: 'created_at', label: 'Created', kind: :datetime, filter_kind: nil, sortable: true)
  end

  # Present only when the form tracks status (TrackableStatus provides the label).
  def status_column
    return [] unless model.method_defined?(:status_label)

    [Registry::Column.new(name: 'status_label', label: 'Status', kind: :status, filter_kind: nil, sortable: false)]
  end

  # Form fields backed by a real column, in page/position order (mirrors the
  # column customizer's table_field_catalog filter).
  def field_columns
    persisted = model.column_names
    template.form_fields
            .reject { |field| NON_DISPLAY_FIELD_TYPES.include?(field.field_type) }
            .select { |field| persisted.include?(field.field_name.to_s) }
            .uniq(&:field_name)
            .sort_by { |field| [field.page_number || 0, field.position || 0] }
            .map do |field|
      Registry::Column.new(
        name: field.field_name.to_s,
        label: field.label.presence || field.field_name.to_s.tr('_', ' ').titleize,
        kind: field.field_type == 'date' ? :date : :text,
        filter_kind: nil,
        sortable: true
      )
    end
  end
end
