# frozen_string_literal: true

module Aim
  # AIM's email alerts (#131): the daily digest, and the second approver's
  # notice. Sent only when AIM_EMAIL_ALERTS=on (Aim::Alerts); from
  # AIM_ALERT_FROM when set, Paperboy's own address otherwise.
  class AlertMailer < ApplicationMailer
    HEADINGS = {
      'owner_past_due' => 'Waiting in your queue',
      'owner_new' => 'New in your queue',
      'bu_admin_duplicates' => 'Possible duplicates in your BUs',
      'bu_admin_shared_past_due' => 'Waiting in your BUs\' shared queues'
    }.freeze

    # +invoice_ids+: { kind => [invoice id, ...] }, as Aim::Alerts#digests has
    # them, so it can be queued.
    def digest(employee_id, invoice_ids)
      @employee = Employee.find_by(id: employee_id)
      return if @employee&.email.blank?

      invoices = Aim::Invoice.where(id: invoice_ids.values.flatten).index_by(&:id)
      @sections = invoice_ids.filter_map do |kind, ids|
        rows = ids.filter_map { |id| invoices[id] }
        [HEADINGS.fetch(kind.to_s, kind.to_s.humanize), rows] if rows.any?
      end
      mail(to: @employee.email, subject: "AIM: #{ActionController::Base.helpers.pluralize(@sections.sum { |_, rows| rows.size }, 'invoice')} need you",
           **sender)
    end

    def second_approval(invoice_id)
      @invoice = Aim::Invoice.find_by(id: invoice_id)
      @employee = Employee.find_by(id: @invoice&.assigned_employee_id)
      return if @employee&.email.blank?

      mail(to: @employee.email, subject: "AIM: second approval needed for #{@invoice.vendor_name} #{@invoice.invoice_number}",
           **sender)
    end

    private

    def sender = Aim::Alerts.from ? { from: Aim::Alerts.from } : {}
  end
end
