# frozen_string_literal: true

# Turns a plain inventory model into a "Records" table: a typed, mutable
# registry surfaced through the shared column-customizer (see TableColumns) and
# optionally fed by a form submission (see RecordIngestion).
#
# Column definitions live in code — one `registry_column` per displayable
# attribute — so standing up a new table is a migration plus a handful of
# declarations. The developer owns the schema; users edit row values.
module Registry
  extend ActiveSupport::Concern

  # One displayable/typed column on the table. `name` is a model attribute (or
  # any reader). `kind` drives cell rendering in TableColumnsHelper;
  # `filter_kind` is nil or a filter kind (:search / :select). Declaration
  # order is the default column order.
  Column = Struct.new(:name, :label, :kind, :filter_kind, :sortable, keyword_init: true)

  included do
    class_attribute :registry_slug, instance_accessor: false
    class_attribute :registry_label, instance_accessor: false
    class_attribute :registry_permission, instance_accessor: false
    class_attribute :registry_dropdown_key, instance_accessor: false
    class_attribute :registry_route, instance_accessor: false
    class_attribute :registry_eager_load, instance_accessor: false
    class_attribute :registry_default_scope, instance_accessor: false
    class_attribute :registry_columns, instance_accessor: false, default: []
    class_attribute :registry_source_config, instance_accessor: false
  end

  class_methods do
    # Declare the table itself.
    #   slug         URL/page key — addressed as the "records:<slug>" page.
    #   permission   group name that grants access (system admins bypass).
    #   dropdown_key ACL dropdown key that also grants access (optional).
    #   route        path-helper name (Symbol) for a bespoke grid screen; omit
    #                to use the generic records grid at /records/<slug>.
    #   includes     association(s) to eager-load for the grid (avoids N+1 when
    #                columns read through a belongs_to).
    #   scope        lambda evaluated on the model, narrowing which rows the
    #                table shows; omit to show every row. Use it when the table
    #                is a view over a subset (e.g. the OSHA 300 Log is only the
    #                approved reports).
    def registry_table(slug:, label:, permission: nil, dropdown_key: nil, route: nil,
                       includes: nil, scope: nil)
      self.registry_slug = slug.to_s
      self.registry_label = label
      self.registry_permission = permission
      self.registry_dropdown_key = dropdown_key
      self.registry_route = route
      self.registry_eager_load = includes
      self.registry_default_scope = scope
    end

    # Declare one column. Call order determines the default column order.
    def registry_column(name, label: nil, kind: :text, filter: nil, sortable: true)
      self.registry_columns += [
        Column.new(name: name.to_s,
                   label: label || name.to_s.tr('_', ' ').titleize,
                   kind: kind, filter_kind: filter, sortable: sortable)
      ]
    end

    # Declare the form that feeds this table and how its fields map to columns.
    # Each mapping value is either a Symbol (read that attribute off the form)
    # or a proc taking the form (for transforms and reference lookups).
    def registry_fed_by(form_class, **mapping)
      self.registry_source_config = { form_class: form_class, mapping: mapping }
    end

    # Create a row from a matching form submission, applying the field mapping.
    # Returns nil (without raising) when the form isn't this table's source.
    def ingest_from(form)
      cfg = registry_source_config
      return nil unless cfg && form.is_a?(cfg[:form_class])

      attrs = cfg[:mapping].transform_values do |source|
        source.respond_to?(:call) ? source.call(form) : form.public_send(source)
      end
      create(attrs)
    end
  end
end
