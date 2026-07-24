# frozen_string_literal: true

require 'test_helper'

class DslOutputsControllerTest < ActionController::TestCase
  tests DataRunner::DslsController

  test 'outputs list includes backup directory link' do
    sign_in
    backup_path = Rails.root.join('output/data_runner/06_Download_Backup', '2099-01-02-001-employees.xlsx')
    backup_path.dirname.mkpath
    backup_path.write('backup')

    get :outputs, params: { name: 'employees' }

    assert_response :success
    assert_select 'td', text: '06_Download_Backup'
    assert_select 'a[href=?]', backup_outputs_data_runner_dsl_path('employees'), text: '06_Download_Backup'
  ensure
    backup_path&.delete if backup_path&.file?
  end

  test 'outputs list uses workflow stages in links' do
    sign_in
    created_files = []
    paths = {
      '01_Download' => 'bdmforcasts.xlsx',
      '02_Normalized' => 'bdmforcasts.csv',
      '03_SQL_MAP' => 'bdmforcasts.sql',
      '05_DSL_Applied' => 'bdmforcasts.csv'
    }
    paths.each do |stage, basename|
      path = WorkflowPaths::OUTPUT_ROOT.join(stage, basename)
      next if path.file?

      path.dirname.mkpath
      path.write('output')
      created_files << path
    end

    get :outputs, params: { name: 'bdmforcasts' }

    assert_response :success
    paths.each do |stage, basename|
      assert_select 'td', text: stage
      assert_select 'a[href=?]',
                    output_data_runner_dsl_path('bdmforcasts', path: "#{stage}/#{basename}"),
                    text: basename
    end
  ensure
    created_files&.each { |path| path.delete if path.file? }
  end

  test 'backup file preview has close action next to download' do
    sign_in
    backup_path = Rails.root.join('output/data_runner/06_Download_Backup', '2099-01-02-001-employees.csv')
    backup_path.dirname.mkpath
    backup_path.write("id,name\n1,Ada\n")

    get :output, params: { name: 'employees', path: '06_Download_Backup/2099-01-02-001-employees.csv' }

    assert_response :success
    assert_select '.output-heading .inline-actions a', text: 'Download file'
    assert_select '.output-heading .inline-actions a[href=?]', backup_outputs_data_runner_dsl_path('employees'), text: 'Close'
  ensure
    backup_path&.delete if backup_path&.file?
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
