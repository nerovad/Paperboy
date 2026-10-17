# frozen_string_literal: true

require 'test_helper'

class SessionsControllerTest < ActionDispatch::IntegrationTest
  EMPLOYEE = Struct.new(:employee_id, :email, :first_name, :last_name, :work_phone,
                        :supervisor_id, :department, :agency, :unit)
                   .new(42, 'admin@example.com', 'Sys', 'Admin', '555-0100', 7,
                        'IT', '10', '1001')

  test 'legacy login is forbidden outside development and test' do
    as_environment('production') do
      Employee.stub(:find_by, EMPLOYEE) do
        post '/login', params: { id: EMPLOYEE.employee_id }
      end
    end

    assert_response :forbidden
    assert_nil session[:user_id]
    assert_nil session[:user]
  end

  test 'legacy login signs in by employee id in development and test' do
    [nil, 'development'].each do |name|
      reset!
      sign_in = lambda do
        Employee.stub(:find_by, EMPLOYEE) do
          post '/login', params: { id: EMPLOYEE.employee_id }
        end
      end
      name ? as_environment(name) { sign_in.call } : sign_in.call

      assert_redirected_to root_path
      assert_equal EMPLOYEE.employee_id, session[:user_id]
      assert_equal 'admin@example.com', session[:user]['email']
    end
  end

  private

  def as_environment(name, &block)
    Rails.stub(:env, ActiveSupport::EnvironmentInquirer.new(name), &block)
  end
end
