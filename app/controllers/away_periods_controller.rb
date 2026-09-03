# frozen_string_literal: true

# Book and cancel your own away cover, from the Settings page.
#
# Strictly personal: the employee id is taken from the session and never from
# the form, so nobody can mark a colleague away or hand somebody else's inbox to
# themselves.
class AwayPeriodsController < ApplicationController
  def create
    period = AwayPeriod.new(away_period_attributes)

    if period.save
      redirect_to settings_path, notice: handover_notice(period)
    else
      redirect_to settings_path, alert: period.errors.full_messages.to_sentence.presence || 'Could not save.'
    end
  end

  def destroy
    period = AwayPeriod.find(params[:id])
    return redirect_to settings_path, alert: "That isn't your away period." unless period.employee_id.to_s == current_employee_id

    period.destroy
    # Nothing is taken back: work already handed over stays with the delegate,
    # the same as a reassignment made by hand. Only the redirect stops.
    redirect_to settings_path, notice: 'Away period cancelled. New work comes back to you.'
  end

  private

  # Hand over straight away when the period has already begun, so somebody
  # setting themselves away this morning does not wait for the overnight job.
  def handover_notice(period)
    return 'Away period saved.' unless period.started?

    result = AwayReassignment.new(period).call
    return 'Away period saved. You had no open tasks to hand over.' if result.moved.zero?

    "Away period saved. #{result.moved} #{'task'.pluralize(result.moved)} handed over."
  end

  def current_employee_id = session.dig(:user, 'employee_id').to_s

  def away_period_attributes
    permitted = params.require(:away_period).permit(:delegate_id, :starts_on, :ends_on)

    {
      employee_id: current_employee_id,
      delegate_id: permitted[:delegate_id],
      starts_on: permitted[:starts_on].presence || Date.current,
      ends_on: permitted[:ends_on]
    }
  end
end
