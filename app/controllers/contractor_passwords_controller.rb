# Handles both the initial "set your password" link (from the welcome email) and
# self-service password resets. Both arrive at #edit carrying a signed,
# stateless token (Contractor#generates_token_for) — no token is stored in the
# DB, and each invalidates once the password changes.
class ContractorPasswordsController < ApplicationController
  MIN_PASSWORD_LENGTH = 10

  # GET — form to request a reset link by email.
  def new; end

  # POST — email a reset link. Always responds the same way to avoid leaking
  # which emails have accounts.
  def create
    contractor = Contractor.find_by('LOWER(email) = ?', params[:email].to_s.strip.downcase)
    ContractorMailer.password_reset(contractor).deliver_later if contractor&.resettable?
    redirect_to contractor_login_path,
                notice: 'If that email matches a contractor account, a reset link has been sent.'
  end

  # GET — the set/reset form, reached from a welcome or reset link.
  def edit
    @contractor = find_by_any_token(params[:token])
    @token = params[:token]
    redirect_to contractor_login_path, alert: invalid_link_message unless @contractor
  end

  # PATCH — set the new password.
  def update
    @contractor = find_by_any_token(params[:token])
    @token = params[:token]
    return redirect_to(contractor_login_path, alert: invalid_link_message) unless @contractor

    password = params[:password].to_s
    confirmation = params[:password_confirmation].to_s

    if password.length < MIN_PASSWORD_LENGTH
      flash.now[:alert] = "Password must be at least #{MIN_PASSWORD_LENGTH} characters."
      return render :edit, status: :unprocessable_entity
    end

    if password != confirmation
      flash.now[:alert] = 'Password and confirmation do not match.'
      return render :edit, status: :unprocessable_entity
    end

    @contractor.update!(password: password)
    redirect_to contractor_login_path, notice: 'Your password has been set. You can now sign in.'
  end

  private

  # A welcome link carries a :password_setup token; a reset link carries a
  # :password_reset token. Either is accepted at this form.
  def find_by_any_token(token)
    return nil if token.blank?

    Contractor.find_by_token_for(:password_setup, token) ||
      Contractor.find_by_token_for(:password_reset, token)
  end

  def invalid_link_message
    'That link is invalid or has expired. Request a new one below.'
  end
end
