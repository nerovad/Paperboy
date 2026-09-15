# frozen_string_literal: true

# Scheduled CSV exports of a Records grid view, managed from the grid's Export
# modal. Anyone who can open a table may schedule its export to themselves —
# the email carries nothing the grid would not show them — and may only see,
# pause or delete their own schedules.
class RecordExportSchedulesController < ApplicationController
  before_action :set_table
  before_action :set_schedule, only: %i[toggle destroy]

  def create
    schedule = ScheduledRecordExport.new(
      schedule_params.merge(
        employee_id: current_employee_id.to_s,
        table_slug: @table.slug,
        view_params: ScheduledRecordExport.view_params_from(request.request_parameters['view']),
        layout: UserSetting.for_employee(current_employee_id).layout_for(@table.page_key)
      )
    )

    if schedule.save
      next_run = schedule.next_run_at.in_time_zone(RecurringSchedule::TIME_ZONE).strftime('%B %d at %I:%M %p')
      redirect_to back_to_grid(schedule), notice: "Export scheduled. First email: #{next_run}."
    else
      redirect_to back_to_grid(schedule), alert: "Could not schedule export: #{schedule.errors.full_messages.join(', ')}"
    end
  end

  def toggle
    @schedule.enabled = !@schedule.enabled
    # A paused schedule's next_run_at is stale; resuming starts from now rather
    # than firing at once for a run it missed.
    @schedule.next_run_at = @schedule.calculate_next_run if @schedule.enabled
    @schedule.save!

    redirect_to back_to_grid(@schedule), notice: "Scheduled export #{@schedule.enabled? ? 'resumed' : 'paused'}."
  end

  def destroy
    @schedule.destroy
    redirect_to back_to_grid(@schedule), notice: 'Scheduled export deleted.'
  end

  private

  def schedule_params
    params.require(:schedule).permit(:frequency, :time_of_day, :day_of_week, :day_of_month)
  end

  # Back to the grid, in the view the schedule was made from.
  def back_to_grid(schedule)
    records_table_path(@table.slug, schedule.view_params || {})
  end

  def set_table
    @table = RegistryTable.find(params[:slug])
    return redirect_to(records_path, alert: 'Unknown table.') unless @table

    redirect_to(root_path, alert: 'Access denied.') unless helpers.can_access_record_table?(@table)
  end

  def set_schedule
    @schedule = ScheduledRecordExport.for_employee(current_employee_id)
                                     .find_by(id: params[:id], table_slug: @table.slug)
    redirect_to(records_table_path(@table.slug), alert: 'Scheduled export not found.') unless @schedule
  end

  def current_employee_id
    session.dig(:user, 'employee_id')
  end
end
