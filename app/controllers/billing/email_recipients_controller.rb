# frozen_string_literal: true

module Billing
  class EmailRecipientsController < BaseController
    before_action :require_system_admin

    def index
      @recipients = EmailRecipient.order(:email_address)
    end

    def create
      recipient = EmailRecipient.new(recipient_params)
      recipient.save!
      redirect_to billing_email_recipients_path, notice: 'Email recipient added.'
    rescue ActiveRecord::ActiveRecordError => e
      Rails.logger.error("Billing recipient add failed: #{e.class}: #{e.message}")
      redirect_to billing_email_recipients_path, alert: 'Email recipient could not be added.'
    end

    def destroy
      EmailRecipient.find(params[:id]).destroy!
      redirect_to billing_email_recipients_path, notice: 'Email recipient removed.'
    rescue ActiveRecord::ActiveRecordError => e
      Rails.logger.error("Billing recipient removal failed: #{e.class}: #{e.message}")
      redirect_to billing_email_recipients_path, alert: 'Email recipient could not be removed.'
    end

    private

    def recipient_params
      params.require(:billing_email_recipient).permit(:email_address)
    end
  end
end
