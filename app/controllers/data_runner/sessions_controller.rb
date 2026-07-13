# frozen_string_literal: true

module DataRunner
  class SessionsController < ApplicationController
    def setup
      head :not_found
    end

    def create_oauth
      email = request.env.dig('omniauth.auth', 'info', 'email').to_s
      employee = Employee.where('LOWER(email) LIKE ?', "#{email.split('@').first.downcase}@%").first
      return redirect_to(data_runner_root_path, alert: 'Employee not found. Contact IT.') unless employee

      sign_in(employee)
      redirect_to data_runner_root_path
    end

    def failure
      redirect_to data_runner_root_path, alert: "Authentication failed: #{params[:message]}"
    end

    def destroy
      reset_session
      redirect_to data_runner_root_path, status: :see_other
    end

    def create_legacy
      return head(:forbidden) unless Rails.env.development?

      employee = Employee.find_by(id: params[:id])
      return redirect_to(data_runner_root_path, alert: 'User not found') unless employee

      sign_in(employee)
      redirect_to data_runner_root_path
    end

    private

    def sign_in(employee)
      session[:user] = {
        'employee_id' => employee.id, 'email' => employee.email,
        'first_name' => employee.first_name, 'last_name' => employee.last_name
      }
    end
  end
end
