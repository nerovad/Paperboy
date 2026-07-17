# frozen_string_literal: true

# View helpers for rendering the customizable "My Work" tables (Inbox +
# Submissions) from a resolved list of TableColumns::Column. Presentation lives
# here; the column metadata/extractors live in TableColumns.
module TableColumnsHelper
  # A sortable <th> link that preserves the current filters (all query params
  # except the sort keys) and shows the active sort indicator. Non-sortable
  # columns render as plain label text.
  def sortable_column_header(column)
    return content_tag(:span, column.label, class: 'th-label') unless column.sortable?

    effective = params[:sort_by].presence || @default_sort
    next_dir = params[:sort_by].to_s == column.sort_key && params[:sort_direction] == 'asc' ? 'desc' : 'asc'
    qp = request.query_parameters.except('sort_by', 'sort_direction')
                .merge('sort_by' => column.sort_key, 'sort_direction' => next_dir)

    link_to "#{request.path}?#{qp.to_query}", class: 'sortable-header', data: { turbo: false } do
      indicator =
        if effective == column.sort_key
          content_tag(:span, (params[:sort_direction] == 'asc' ? '▲' : '▼'), class: 'sort-indicator')
        else
          ''.html_safe
        end
      safe_join([column.label, ' ', indicator])
    end
  end

  # Rendered cell content for a column + row. Inbox rows are AR instances;
  # Submissions rows are item Hashes — the reference/status branches key off that.
  def table_cell_content(column, row)
    case column.kind
    when :reference
      ref = row.is_a?(Hash) ? row[:reference] : inbox_reference(row)
      content_tag(:span, ref, class: 'reference-badge')
    when :status
      status_badge_cell(row)
    when :datetime
      format_pst(column.value&.call(row)) || '—'
    when :date
      value = column.value&.call(row)
      value ? value.strftime('%m/%d/%Y') : '—'
    when :currency
      value = column.value&.call(row)
      value.present? ? number_to_currency(value) : '—'
    else
      value = column.value&.call(row)
      value.present? ? value : '—'
    end
  end

  # Status badge cell. Submissions rows are Hashes carrying an explicit
  # category; AR rows either expose their own badge category (Records tables) or
  # fall back to deriving one from the status label (Inbox).
  def status_badge_cell(row)
    if row.is_a?(Hash)
      content_tag(:span, row[:status].to_s.tr('_', ' '),
                  class: "badge #{category_badge_class(row[:status_category])}")
    elsif row.respond_to?(:status_badge_category)
      content_tag(:span, row.status_label,
                  class: "badge #{category_badge_class(row.status_badge_category)}")
    else
      content_tag(:span, row.status_label,
                  class: "badge #{status_badge_class(row.status_label)}")
    end
  end

  # data-* attributes for a column's filter control. Preserves the status-filters
  # Stimulus wiring for the Submissions type/status dropdowns.
  def column_filter_data(column, page)
    attrs = { action: 'change->auto-submit#submit' }
    if page.to_s == 'submissions' && column.id == 'type'
      attrs[:status_filters_target] = 'type'
      attrs[:action] = 'change->status-filters#typeChanged change->auto-submit#submit'
    elsif page.to_s == 'submissions' && column.id == 'status'
      attrs[:status_filters_target] = 'status'
    end
    attrs
  end

  # Built-in columns available to add (not currently shown), respecting the
  # employee-column permission on Submissions.
  def available_builtin_columns(page, shown_columns, employee_column: true)
    shown_ids = shown_columns.map(&:id)
    TableColumns.builtins(page).filter_map do |key, cfg|
      next if shown_ids.include?(key)
      next if cfg[:permission] && cfg[:permission] == :employee_column && !employee_column

      [key, cfg[:label]]
    end
  end
end
