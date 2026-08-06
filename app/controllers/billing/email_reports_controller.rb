# frozen_string_literal: true

module Billing
  class EmailReportsController < BaseController
    before_action :require_system_admin
    before_action :load_active_billing_period
    before_action :load_reports

    def show
      @selected_names = default_selected_names
    end

    def create
      @selected_names = selected_names
      selected_reports = @reports.select { |report| @selected_names.include?(report.name) }
      return render_selection_error if selected_reports.empty?

      delivery = EmailDelivery.new(reports: selected_reports, active_period: @active_billing_period)
      if params[:commit] == 'Preview'
        @preview_output = preview(delivery.messages)
        render :show
      else
        send_reports(delivery)
      end
    rescue StandardError => e
      Rails.logger.error("Billing email failed: #{e.class}: #{e.message}")
      flash.now[:alert] = 'Billing reports could not be emailed.'
      render :show, status: :unprocessable_entity
    end

    private

    def load_active_billing_period
      @active_billing_period = ActiveBillingPeriod.current
      return if @active_billing_period

      redirect_to billing_reporting_period_path,
                  alert: 'Select an active billing period before emailing Billing reports.'
    end

    def load_reports
      @reports = EmailReport.all
      @active_types = BillingType.where(ACTIVE: true).pluck(:TYPE).to_set
    end

    def default_selected_names
      @reports.select { |report| report.active_by_default?(@active_types) }.to_set(&:name)
    end

    def selected_names
      allowed = @reports.map(&:name)
      params.fetch(:reports, {}).permit(*allowed).to_h.select { |_name, value| value == '1' }.keys.to_set
    end

    def render_selection_error
      flash.now[:alert] = 'Select at least one Billing report.'
      render :show, status: :unprocessable_entity
    end

    def send_reports(delivery)
      recipients = EmailRecipient.order(:email_address).pluck(:email_address)
      if recipients.empty?
        flash.now[:alert] = 'Add at least one email recipient before sending.'
        return render :show, status: :unprocessable_entity
      end

      delivery.deliver(recipients)
      redirect_to billing_reports_path, notice: 'Billing reports emailed successfully.'
    end

    def preview(messages)
      recipients = EmailRecipient.order(:email_address).pluck(:email_address)
      messages.map.with_index(1) do |message, index|
        <<~PREVIEW
          Email #{index}
          To: #{recipients.presence&.join(', ') || '(no recipients configured)'}
          Subject: #{message.subject}
          Body: #{message.body}
          Attachments:
          #{message.attachments.map { |file| "- #{file.filename}" }.join("\n")}
        PREVIEW
      end.join("\n")
    end
  end
end
