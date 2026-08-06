# frozen_string_literal: true

module Billing
  class EmailRecipient < BillingBase
    self.table_name = 'GSABSS.dbo.Billing_Email_Recipients'

    validates :email_address, presence: true,
                              format: { with: URI::MailTo::EMAIL_REGEXP },
                              uniqueness: { case_sensitive: false }
  end
end
