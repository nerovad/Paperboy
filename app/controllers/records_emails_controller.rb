# frozen_string_literal: true

# "Send now" in a Records grid's Email dialog: the view on screen -- its
# search, filters, sort and the sender's columns -- emailed to county employees
# as a CSV. See RecordsEmailRulesController for the standing rules.
class RecordsEmailsController < ApplicationController
  include RecordsEmailDialog

  def create
    to = RecordsEmailRecipients.parse(params.dig(:email, :recipients))
    outsiders = RecordsEmailRecipients.outsiders(to)
    return redirect_to(back_to_grid, alert: 'Enter at least one email address.') if to.empty?
    if outsiders.any?
      return redirect_to(back_to_grid, alert: "Not sent: #{outsiders.join(', ')} " \
                                              "#{outsiders.one? ? 'is not a county employee' : 'are not county employees'}.")
    end

    view = grid_view
    return redirect_to(back_to_grid, alert: 'Not sent: this view has no rows.') if view.rows.empty?

    send_view(view, to)
    redirect_to back_to_grid, notice: "Emailed #{helpers.pluralize(view.rows.size, 'row')} to #{to.join(', ')}."
  end

  private

  def grid_view
    layout = UserSetting.for_employee(current_employee_id).layout_for(@table.page_key)
    RecordsView.new(@table, layout: layout, params: view_params.with_indifferent_access)
  end

  def view_params
    ScheduledRecordExport.view_params_from(request.request_parameters['view'])
  end

  def send_view(view, to)
    mail = RecordsMailer.view_rows(table: @table, sender: session[:user] || {}, to: to,
                                   csv: RecordsCsv.generate(view), row_count: view.rows.size,
                                   note: params.dig(:email, :note).to_s.strip.first(1000),
                                   view_description: ScheduledRecordExport.describe_view(@table, view_params))
    mail.deliver_now

    RecordsEmailDelivery.create!(table_slug: @table.slug, subject: mail.subject, recipients: to.join(', '),
                                 row_count: view.rows.size, sent_by_employee_id: current_employee_id.to_s)
  end
end
