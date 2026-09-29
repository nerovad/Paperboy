# frozen_string_literal: true

require 'test_helper'

module Aim
  # Upload follows the person (2026-09-29): an invoice for someone goes in
  # one of their budget units. Refused before anything is stored.
  class UploadUnitsTest < ActionController::TestCase
    tests Aim::UploadsController

    setup do
      session[:user] = { 'email' => 'jane@example.com', 'employee_id' => 42, 'unit' => '4601' }
      @controller.define_singleton_method(:current_user_group_names) { Set['system_admins'] }
    end

    test 'an invoice for someone goes in one of their budget units' do
      employee = Employee.order(:id).first || skip('no employee to test with')
      file = Rack::Test::UploadedFile.new(StringIO.new("%PDF-1.4 a\n"), 'application/pdf', original_filename: 'a.pdf')

      Aim::Users.stub(:member?, true) do
        Aim::Users.stub(:budget_units_of, ['4641']) do
          post :create, params: { budget_unit: '4601', owner: 'person', owner_employee_id: employee.id, files: [file] }
        end
      end

      assert_match(/do not work in 4601/, flash[:alert])
      assert_equal 0, Aim::Invoice.count
    end
  end
end
