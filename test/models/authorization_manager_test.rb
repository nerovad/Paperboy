# frozen_string_literal: true

require 'test_helper'

class AuthorizationManagerTest < ActiveSupport::TestCase
  Person = Struct.new(:full_name, :email)
  Units = Struct.new(:department_id) do
    def pick(_column) = department_id
  end

  setup { AuthorizationManager.delete_all }

  test 'a blocked submitter is told who manages their department' do
    AuthorizationManager.create!(employee_id: '100', department_id: '4600')
    AuthorizationManager.create!(employee_id: '200', department_id: '4600').remove!(removed_by: '1')
    asked = nil
    employees = lambda { |conditions|
      asked = conditions
      [Person.new('Pat Lee', 'pat@example.com')]
    }

    message = Coa::Unit.stub(:where, ->(*) { Units.new('4600') }) do
      Employee.stub(:where, employees) { AuthorizationManager.no_approver_message('Parking Permits', '4601') }
    end

    assert_equal({ id: ['100'] }, asked)
    assert_equal 'No authorized approver found for Parking Permits in your budget unit. ' \
                 "Please contact your department's authorization manager: Pat Lee (pat@example.com).", message
  end

  test 'the message keeps its old wording when there is nobody to name' do
    message = Coa::Unit.stub(:where, ->(*) { Units.new(nil) }) do
      AuthorizationManager.no_approver_message('Parking Permits', '4601')
    end

    assert_equal 'No authorized approver found for Parking Permits in your budget unit. ' \
                 "Please contact your department's authorization manager.", message
  end

  test 'a failed lookup names nobody rather than failing the form' do
    assert_empty Coa::Unit.stub(:where, ->(*) { raise 'GSABSS is down' }) { AuthorizationManager.contacts_for_unit('4601') }
  end
end
