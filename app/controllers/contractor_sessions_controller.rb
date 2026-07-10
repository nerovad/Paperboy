# frozen_string_literal: true

# Password-based login for contractors (non-Active-Directory users). Employees
# sign in through Entra ID (SessionsController); contractors have no AD account,
# so they authenticate with email + password here. On success we build the SAME
# session[:user] / session[:user_id] shape employees get, so every downstream
# current_user / permission / routing consumer treats them identically. A
# session[:contractor] marker records the identity source.
class ContractorSessionsController < ApplicationController
  def new; end

  def create
    contractor = Contractor.find_by('LOWER(email) = ?', params[:email].to_s.strip.downcase)

    if contractor&.login_allowed? && contractor.authenticate(params[:password])
      reset_session # guard against session fixation
      set_contractor_session(contractor)
      redirect_to root_path, notice: 'Signed in.'
    elsif contractor && !contractor.login_allowed?
      redirect_to contractor_login_path, alert: login_blocked_message(contractor)
    else
      flash.now[:alert] = 'Invalid email or password.'
      render :new, status: :unprocessable_entity
    end
  end

  def destroy
    reset_session
    redirect_to contractor_login_path, notice: 'Signed out.'
  end

  private

  def set_contractor_session(contractor)
    session[:user_id]    = contractor.id
    session[:contractor] = true
    session[:user] = {
      'email' => contractor.email,
      'first_name' => contractor.first_name,
      'last_name' => contractor.last_name,
      'employee_id' => contractor.id,
      'phone' => contractor.work_phone,
      'supervisor_id' => contractor.supervisor_id,
      'department' => contractor.department,
      'agency' => contractor.agency,
      'unit' => contractor.unit
    }
  end

  def login_blocked_message(contractor)
    if contractor.password_digest.blank?
      "Your account isn't set up yet. Check your email for a link to set your password."
    elsif contractor.expired?
      'Your contractor account has expired. Please contact your administrator.'
    else
      'Your contractor account is inactive. Please contact your administrator.'
    end
  end
end
