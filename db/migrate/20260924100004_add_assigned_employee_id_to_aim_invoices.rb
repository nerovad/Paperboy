# frozen_string_literal: true

# Whose queue an invoice is in, as a person: the GSABSS employee id (the same
# id Emulate picks). assigned_to keeps the display name beside it. AIM v2.
class AddAssignedEmployeeIdToAimInvoices < ActiveRecord::Migration[8.1]
  def change
    add_column 'aim.invoices', :assigned_employee_id, :integer
    add_index 'aim.invoices', :assigned_employee_id, name: 'index_aim_invoices_on_assigned_employee_id'
  end
end
