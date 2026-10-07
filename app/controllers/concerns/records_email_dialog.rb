# frozen_string_literal: true

# Shared by the controllers behind a Records grid's Email dialog. Everything in
# it sends a table's rows to other people or decides who they go to, so all of
# it needs the table's edit grant (Records Editing, or a system admin) -- being
# able to open a grid is not enough.
module RecordsEmailDialog
  extend ActiveSupport::Concern

  included do
    before_action :set_table
  end

  private

  # Back to the grid in the view it was left in, with the dialog open again:
  # setting up a rule and its contacts takes several submissions.
  def back_to_grid
    view = ScheduledRecordExport.view_params_from(request.request_parameters['view'])
    records_table_path(@table.slug, view.merge(email: 'open'))
  end

  def set_table
    @table = RegistryTable.find(params[:slug])
    return redirect_to(records_path, alert: 'Unknown table.') unless @table

    redirect_to(root_path, alert: 'Access denied.') unless helpers.can_edit_record_table?(@table)
  end

  def current_employee_id
    session.dig(:user, 'employee_id')
  end
end
