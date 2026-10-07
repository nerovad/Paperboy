# frozen_string_literal: true

# A Records table's email rules, managed from the grid's Email dialog by the
# table's editors. Rules belong to the table, so any editor may pause, run or
# delete one; resuming or adding one makes that editor its owner, the person
# whose grant each run is checked against. See RecordsEmailRule.
class RecordsEmailRulesController < ApplicationController
  include RecordsEmailDialog

  before_action :set_rule, only: %i[toggle deliver destroy]

  def create
    rule = RecordsEmailRule.new(rule_params.merge(table_slug: @table.slug, employee_id: current_employee_id.to_s))
    rule.recipients = nil if rule.split?

    if rule.save
      next_run = rule.next_run_at.in_time_zone(RecurringSchedule::TIME_ZONE).strftime('%B %d at %I:%M %p')
      redirect_to back_to_grid, notice: "Email rule added: #{rule.label}. First run: #{next_run}."
    else
      redirect_to back_to_grid, alert: "Could not add email rule: #{rule.errors.full_messages.join(', ')}"
    end
  end

  def toggle
    @rule.enabled = !@rule.enabled
    if @rule.enabled
      # A paused rule's next_run_at is stale; resuming starts from now rather
      # than firing at once for a run it missed.
      @rule.next_run_at = @rule.calculate_next_run
      @rule.employee_id = current_employee_id.to_s
    end
    @rule.save!

    redirect_to back_to_grid, notice: "Email rule #{@rule.enabled? ? 'resumed' : 'paused'}."
  end

  # Run it now, whatever its schedule says and whether or not it is paused.
  def deliver
    RecordsEmailRuleJob.perform_later(@rule.id, manual: true)
    count = @rule.matching_rows.size

    notice = count.zero? ? 'No rows meet this rule today, so nothing was sent.' : "Sending #{helpers.pluralize(count, 'row')} now."
    redirect_to back_to_grid, notice: notice
  end

  def destroy
    @rule.destroy
    redirect_to back_to_grid, notice: 'Email rule deleted.'
  end

  private

  def rule_params
    params.require(:rule).permit(:label, :column_name, :operator, :value, :message, :split_column, :recipients,
                                 :frequency, :time_of_day, :day_of_week, :day_of_month)
  end

  def set_rule
    @rule = RecordsEmailRule.for_table(@table.slug).find_by(id: params[:id])
    redirect_to(back_to_grid, alert: 'Email rule not found.') unless @rule
  end
end
