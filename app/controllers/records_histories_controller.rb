# frozen_string_literal: true

require 'csv'

# The change history of a Records table: a filterable log of every edit, row
# added and row deleted (index, also downloadable as CSV), and one row's
# history as a fragment for the grid's History modal (row).
#
# Visibility follows the edit grant, not view access, the same rule the
# submission Edit History keeps: a trail names who changed what, so whoever may
# rewrite a table may see who already has.
class RecordsHistoriesController < ApplicationController
  include Pagy::Method

  # RecordEdit rows (one per column) per page of the change log.
  PAGE_SIZE = 200

  FILTERS = %i[changed_by column_name change from to].freeze

  before_action :set_table

  def index
    edits = filtered(@history.edits)

    respond_to do |format|
      format.html do
        @people = @history.edits.where.not(changed_by_name: [nil, '']).distinct.pluck(:changed_by_name).sort
        @column_names = @history.edits.distinct.pluck(:column_name).sort
        @pagy, rows = pagy(:offset, edits.newest_first, limit: PAGE_SIZE)
        @entries = Forms::EditTrail.for_rows(@table.model, rows).reverse
        @row_labels = @history.row_labels(@entries)
      end
      format.csv do
        entries = Forms::EditTrail.for_rows(@table.model, edits).reverse
        send_data changes_csv(entries, @history.row_labels(entries)),
                  filename: "#{@table.slug}-changes-#{Date.current.iso8601}.csv", type: 'text/csv'
      end
    end
  end

  def row
    return head :not_found unless @history.row?(params[:id])

    render partial: 'submissions/edit_timeline',
           locals: { entries: @history.row_entries(params[:id]),
                     item_id: "records-#{@table.slug}-#{params[:id].to_i}",
                     empty_message: 'No changes have been recorded for this row.' },
           layout: false
  end

  private

  def set_table
    @table = RegistryTable.find(params[:slug])
    return head(:not_found) if @table.nil? && action_name == 'row'
    return redirect_to(records_path, alert: 'Unknown table.') unless @table

    unless helpers.can_edit_record_table?(@table)
      return head(:forbidden) if action_name == 'row'

      return redirect_to(root_path, alert: 'Access denied.')
    end

    @history = RecordsHistory.new(@table)
  end

  def filtered(edits)
    edits = edits.where(changed_by_name: params[:changed_by]) if params[:changed_by].present?
    edits = edits.where(column_name: params[:column_name]) if params[:column_name].present?
    edits = edits.where(action: params[:change]) if RecordEdit::ACTIONS.include?(params[:change])
    edits = edits.where(created_at: day(params[:from]).beginning_of_day..) if day(params[:from])
    edits = edits.where(created_at: ..day(params[:to]).end_of_day) if day(params[:to])
    edits
  end

  # Dates are entered in county time.
  def day(value)
    Date.iso8601(value.to_s).in_time_zone(RecurringSchedule::TIME_ZONE)
  rescue Date::Error
    nil
  end

  def changes_csv(entries, row_labels)
    CSV.generate do |csv|
      csv << ['Changed At', 'Changed By', 'Changed By ID', 'Change', 'Row', 'Record ID', 'Field', 'Old Value',
              'New Value']
      entries.each do |entry|
        entry.changes.each do |change|
          csv << [entry.at.in_time_zone(RecurringSchedule::TIME_ZONE).strftime('%Y-%m-%d %H:%M:%S'),
                  entry.actor_name, entry.actor_id, RecordEdit::ACTION_LABELS[entry.action],
                  row_labels[entry.record_id], entry.record_id, change.label,
                  change.old_value, change.new_value].map { |cell| RecordsCsv.defuse(cell.to_s) }
        end
      end
    end
  end
end
