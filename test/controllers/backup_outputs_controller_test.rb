# frozen_string_literal: true

require 'test_helper'

class BackupOutputsControllerTest < ActionController::TestCase
  tests DataRunner::BackupOutputsController

  test 'backup outputs list sorts by file size and modified' do
    sign_in
    backup_dir = Rails.root.join('output/data_runner/06_Download_Backup')
    small = backup_dir.join('2099-01-03-001-employees.csv')
    large = backup_dir.join('2099-01-04-001-employees.csv')
    backup_dir.mkpath
    small.write("id\n1\n")
    large.write("id,name\n1,Ada\n")
    File.utime(Time.local(2099, 1, 3), Time.local(2099, 1, 3), small)
    File.utime(Time.local(2099, 1, 4), Time.local(2099, 1, 4), large)

    get :index, params: { name: 'employees', sort: 'size', direction: 'desc' }

    assert_response :success
    assert_operator response.body.index(large.basename.to_s), :<, response.body.index(small.basename.to_s)
    assert_select 'th a[href=?]', backup_outputs_data_runner_dsl_path('employees', sort: 'file', direction: 'asc'), text: 'File'
    assert_select 'th a[href=?]', backup_outputs_data_runner_dsl_path('employees', sort: 'size', direction: 'asc'), text: 'Size'

    get :index, params: { name: 'employees', sort: 'modified', direction: 'asc' }

    assert_response :success
    assert_operator response.body.index(small.basename.to_s), :<, response.body.index(large.basename.to_s)
    assert_select 'th a[href=?]', backup_outputs_data_runner_dsl_path('employees', sort: 'modified', direction: 'desc'),
                  text: 'Modified'
  ensure
    small&.delete if small&.file?
    large&.delete if large&.file?
  end

  test 'all backup files for dsl can be deleted' do
    sign_in
    backup_dir = Rails.root.join('output/data_runner/06_Download_Backup')
    employee_backup = backup_dir.join('2099-01-01-001-employees.xlsx')
    other_backup = backup_dir.join('2099-01-01-001-units.xlsx')
    backup_dir.mkpath
    employee_backup.write('backup')
    other_backup.write('other')

    delete :destroy_all, params: { name: 'employees' }

    assert_redirected_to backup_outputs_data_runner_dsl_path('employees')
    assert_not employee_backup.exist?
    assert other_backup.exist?
  ensure
    employee_backup&.delete if employee_backup&.file?
    other_backup&.delete if other_backup&.file?
  end

  private

  def sign_in
    session[:user] = {
      'employee_id' => 1,
      'email' => 'employee@example.com',
      'first_name' => 'Test',
      'last_name' => 'User'
    }
  end
end
