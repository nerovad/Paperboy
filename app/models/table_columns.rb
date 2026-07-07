# Single source of truth for the customizable columns on the "My Work" tables
# (Inbox queue + Submissions index). Pure metadata + raw-value extractors — no
# view helpers — so it can be used from both controllers and the UserSetting
# layout persistence. Presentation (badges, date formatting) is applied in the
# views by switching on Column#kind.
#
# Rows differ per page: Inbox rows are ActiveRecord submission instances;
# Submissions rows are the item Hashes built by SubmissionsController#build_status_item.
class TableColumns
  PAGES = %i[inbox submissions].freeze

  # A resolved column. `value` is the raw extractor used for filtering, sorting
  # and building filter-dropdown options; it returns comparable primitives, not
  # HTML. `kind` tells the view how to render the cell.
  class Column
    attr_reader :id, :label, :sort_key, :kind, :filter_param, :filter_kind,
                :form, :field, :value

    def initialize(id:, label:, sort_key:, kind:, locked: false, custom: false,
                   filter_param: nil, filter_kind: nil, form: nil, field: nil, value: nil)
      @id = id
      @label = label
      @sort_key = sort_key
      @kind = kind
      @locked = locked
      @custom = custom
      @filter_param = filter_param
      @filter_kind = filter_kind
      @form = form
      @field = field
      @value = value
    end

    def locked? = @locked
    def custom? = @custom
    def filterable? = @filter_param.present?
    def select_filter? = @filter_kind == :select
    def search_filter? = @filter_kind == :search
    def sortable? = @sort_key.present?
  end

  # Built-in column definitions per page. Order here is the normalized default.
  # value: raw extractor (row -> comparable). filter: nil or {param:, kind:}.
  def self.builtins(page)
    case page.to_sym
    when :inbox       then inbox_builtins
    when :submissions then submissions_builtins
    else {}
    end
  end

  def self.inbox_builtins
    {
      "reference"  => { label: "ID",           sort: "reference",  kind: :reference, locked: true,
                        filter: { param: :filter_reference, kind: :search }, value: nil },
      "form_type"  => { label: "Form",         sort: "form_type",  kind: :text,
                        filter: { param: :filter_form_type, kind: :select },
                        value: ->(s) { s.class.name.demodulize.titleize } },
      "name"       => { label: "Employee",     sort: "name",       kind: :text,
                        value: ->(s) { s.name } },
      "unit"       => { label: "Unit",         sort: "unit",       kind: :text,
                        filter: { param: :filter_unit, kind: :select },
                        value: ->(s) { s.try(:unit) } },
      "email"      => { label: "Email",        sort: "email",      kind: :text,
                        filter: { param: :filter_email, kind: :select },
                        value: ->(s) { s.try(:email) } },
      "status"     => { label: "Status",       sort: "status",     kind: :status,
                        filter: { param: :filter_status, kind: :select },
                        value: ->(s) { s.status_label } },
      "created_at" => { label: "Created",      sort: "created_at", kind: :datetime,
                        value: ->(s) { s.created_at } },
      "updated_at" => { label: "Last Updated", sort: "updated_at", kind: :datetime,
                        value: ->(s) { s.updated_at } }
    }
  end

  def self.submissions_builtins
    {
      "reference"     => { label: "ID",           sort: "reference",     kind: :reference, locked: true,
                           filter: { param: :filter_reference, kind: :search },
                           value: ->(i) { i[:reference] } },
      "type"          => { label: "Form",         sort: "type",          kind: :text,
                           filter: { param: :filter_type, kind: :select },
                           value: ->(i) { i[:type] } },
      "employee_name" => { label: "Employee",     sort: "employee_name", kind: :text, permission: :employee_column,
                           value: ->(i) { i[:employee_name] } },
      "unit"          => { label: "Unit",         sort: "unit",          kind: :text,
                           filter: { param: :filter_unit, kind: :select },
                           value: ->(i) { i[:unit] } },
      "status"        => { label: "Status",       sort: "status",        kind: :status,
                           filter: { param: :filter_status, kind: :select },
                           value: ->(i) { i[:status].to_s.tr("_", " ").titleize } },
      "submitted_at"  => { label: "Created",      sort: "submitted_at",  kind: :datetime,
                           value: ->(i) { i[:submitted_at] } },
      "updated_at"    => { label: "Last Updated", sort: "updated_at",    kind: :datetime,
                           value: ->(i) { i[:updated_at] } }
    }
  end

  # The normalized default layout shown when a user hasn't customized. A subset
  # of the built-ins — e.g. Email is addable but hidden by default on the inbox.
  DEFAULT_LAYOUTS = {
    inbox:       %w[reference form_type name unit status created_at updated_at],
    submissions: %w[reference type employee_name unit status submitted_at updated_at]
  }.freeze

  def self.default_layout(page)
    DEFAULT_LAYOUTS.fetch(page.to_sym, builtins(page).keys)
  end

  # Structurally normalize a stored/submitted layout: keep known built-in keys
  # and well-formed custom-field descriptors, dedupe, and guarantee locked
  # columns are present (prepended). Does NOT hit the DB — deep validation of a
  # custom form/field happens where the catalog is available.
  def self.sanitize_layout(page, fields)
    keys = builtins(page).keys
    seen = {}
    result = []

    Array(fields).each do |entry|
      if entry.is_a?(String) || entry.is_a?(Symbol)
        key = entry.to_s
        next unless keys.include?(key)
        next if seen[key]
        seen[key] = true
        result << key
      elsif entry.respond_to?(:[])
        form  = (entry["form"]  || entry[:form]).to_s
        field = (entry["field"] || entry[:field]).to_s
        next if form.blank? || field.blank?
        cid = custom_id(form, field)
        next if seen[cid]
        seen[cid] = true
        label = (entry["label"] || entry[:label]).presence || field.tr("_", " ").titleize
        result << { "type" => "field", "form" => form, "field" => field, "label" => label }
      end
    end

    builtins(page).each do |key, cfg|
      next unless cfg[:locked]
      next if seen[key]
      result.unshift(key)
    end

    result
  end

  # Resolve a layout into ordered Column objects. `context` gates permission
  # columns, e.g. resolve(:submissions, layout, context: { employee_column: true }).
  def self.resolve(page, layout, context: {})
    defs = builtins(page)
    sanitize_layout(page, layout).filter_map do |entry|
      if entry.is_a?(String)
        cfg = defs[entry]
        next unless cfg
        next if cfg[:permission] && !context[cfg[:permission]]
        Column.new(
          id: entry, label: cfg[:label], sort_key: cfg[:sort], kind: cfg[:kind],
          locked: cfg[:locked], custom: false,
          filter_param: cfg.dig(:filter, :param), filter_kind: cfg.dig(:filter, :kind),
          value: cfg[:value]
        )
      else
        build_custom_column(page, entry["form"], entry["field"], entry["label"])
      end
    end
  end

  def self.build_custom_column(page, form, field, label)
    cid = custom_id(form, field)
    extractor =
      if page.to_sym == :submissions
        ->(i) { i.is_a?(Hash) ? i.dig(:custom, cid) : nil }
      else
        ->(s) { s.respond_to?(field) ? s.public_send(field) : nil }
      end

    Column.new(
      id: cid,
      label: label.presence || field.to_s.tr("_", " ").titleize,
      sort_key: cid,
      kind: :text,
      custom: true,
      form: form,
      field: field,
      filter_param: "filter_#{cid.gsub(/[^0-9a-z]+/i, '_').downcase}",
      filter_kind: :select,
      value: extractor
    )
  end

  def self.custom_id(form, field)
    "field::#{form}::#{field}"
  end
end
