# frozen_string_literal: true

# A Records table's highlight rules, managed from the grid's Highlights dialog.
# Everyone who can open the table sees the colours; only its editors (the
# Records Editing grant, or a system admin) may add, reorder or remove rules.
class RecordsHighlightRulesController < ApplicationController
  before_action :set_table
  before_action :set_rule, only: %i[destroy move]

  def create
    rule = RecordsHighlightRule.new(
      rule_params.merge(table_slug: @table.slug, created_by_employee_id: current_employee_id,
                        position: (RecordsHighlightRule.for_table(@table.slug).maximum(:position) || -1) + 1)
    )

    if rule.save
      redirect_to back_to_grid, notice: "Highlight added: #{rule.display_label}."
    else
      redirect_to back_to_grid, alert: "Could not add highlight: #{rule.errors.full_messages.join(', ')}"
    end
  end

  # One step up the list, so it is checked before the rule above it.
  def move
    rules = RecordsHighlightRule.for_table(@table.slug).to_a
    index = rules.index(@rule)
    rules.insert(index - 1, rules.delete_at(index)) if index.positive?
    RecordsHighlightRule.transaction do
      rules.each_with_index { |rule, position| rule.update!(position: position) }
    end

    redirect_to back_to_grid
  end

  def destroy
    @rule.destroy
    redirect_to back_to_grid, notice: 'Highlight removed.'
  end

  private

  def rule_params
    params.require(:rule).permit(:column_name, :operator, :value, :color, :label)
  end

  # Back to the grid in the view it was left in.
  def back_to_grid
    records_table_path(@table.slug, ScheduledRecordExport.view_params_from(request.request_parameters['view']))
  end

  def set_table
    @table = RegistryTable.find(params[:slug])
    return redirect_to(records_path, alert: 'Unknown table.') unless @table

    redirect_to(root_path, alert: 'Access denied.') unless helpers.can_edit_record_table?(@table)
  end

  def set_rule
    @rule = RecordsHighlightRule.for_table(@table.slug).find(params[:id])
  end

  def current_employee_id
    session.dig(:user, 'employee_id')
  end
end
