# frozen_string_literal: true

# Generic grid for a Records table (see Registry) that has no bespoke screen of
# its own. Renders the customizable, sortable column table shared with
# Inbox/Submissions. Tables that declare a `route:` (e.g. P-Cards) are bounced
# to their own richer screen instead.
class RecordsTableController < ApplicationController
  include Filterable

  before_action :set_table, only: :show

  def show
    @page = @table.page_key
    @layout = UserSetting.for_employee(current_employee_id).layout_for(@page)
    @columns = TableColumns.resolve(@page, @layout)

    rows = @table.scope.to_a
    @default_sort = default_sort_key(@columns)
    sort_by = params[:sort_by].presence || @default_sort
    sort_direction = params[:sort_direction] || 'asc'
    sort_configs = @columns.select(&:sortable?).index_by(&:sort_key).transform_values(&:value)

    @records = sort_collection(rows, sort_by, sort_direction, sort_configs, default_sort: @default_sort)
  end

  # Finalize a batch of staged inline edits (from the review modal). Every
  # change is validated against the editable-column whitelist, applied inside a
  # single transaction (all-or-nothing), and the re-rendered cell HTML is
  # returned keyed by "id::column" so the grid can format each cell consistently.
  def bulk_update
    table = RegistryTable.find(params[:slug])
    return head :not_found unless table
    return head :forbidden unless helpers.can_access_record_table?(table)

    changes = Array(params.permit(changes: %i[id column value])[:changes])
    return render(json: { ok: true, cells: {} }) if changes.empty?
    unless changes.all? { |c| RecordsEditing.editable?(table, c[:column]) }
      return render(json: { ok: false, errors: ['One or more columns are not editable.'] },
                    status: :unprocessable_entity)
    end

    render json: { ok: true, cells: apply_changes(table, changes) }
  rescue ActiveRecord::RecordInvalid => e
    render json: { ok: false, errors: e.record.errors.full_messages }, status: :unprocessable_entity
  rescue ActiveRecord::RecordNotFound
    head :not_found
  end

  private

  # Apply the changes atomically and return { "id::column" => cell_html }.
  def apply_changes(table, changes)
    cells = {}
    resolved = {}
    ActiveRecord::Base.transaction do
      changes.group_by { |c| c[:id] }.each do |id, group|
        record = table.model.find(id)
        group.each { |c| record[c[:column]] = c[:value] }
        record.save!
        group.each do |c|
          column = (resolved[c[:column]] ||= TableColumns.resolve(table.page_key, [c[:column]]).first)
          cells["#{id}::#{c[:column]}"] = helpers.table_cell_content(column, record)
        end
      end
    end
    cells
  end

  def set_table
    @table = RegistryTable.find(params[:slug])
    return redirect_to(records_path, alert: 'Unknown table.') unless @table
    return redirect_to(root_path, alert: 'Access denied.') unless helpers.can_access_record_table?(@table)

    # A table with its own screen is served there, not by the generic grid.
    redirect_to(public_send(@table.route)) if @table.route.present?
  end

  def current_employee_id
    session.dig(:user, 'employee_id')
  end
end
