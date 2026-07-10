class ContractorMailer < ApplicationMailer
  # Sent when a system admin provisions a contractor. No password exists yet;
  # this link lets them set one. The setup token invalidates once used (the
  # password digest enters the signing payload) and after 7 days.
  def welcome(contractor)
    @contractor = contractor
    token = contractor.generate_token_for(:password_setup)
    @url = edit_contractor_password_url(token: token)
    mail(to: @contractor.email, subject: 'Set up your GSA Forms contractor account')
  end

  # Self-service / admin-triggered password reset. Token valid for 2 hours.
  def password_reset(contractor)
    @contractor = contractor
    token = contractor.generate_token_for(:password_reset)
    @url = edit_contractor_password_url(token: token)
    mail(to: @contractor.email, subject: 'Reset your GSA Forms password')
  end
end
