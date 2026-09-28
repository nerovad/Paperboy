# frozen_string_literal: true

module Aim
  # What the Fiscal page saves: Fiscal's own fields, and corrections to the
  # invoice's (item f). Needs @record and @invoice.
  module FiscalEdits
    extend ActiveSupport::Concern
    include Aim::CodingLineEdits

    private

    # An archived invoice is finished; nothing on it changes.
    def save_fields
      return if @record.status == 'archived'

      permitted = params.fetch(:fiscal_record, {}).permit(*Aim::FiscalRecord::EDITABLE_FIELDS).to_h
      @record.update!(tidy(permitted).merge(updated_by: current_user_email)) if permitted.any?
      save_invoice_fields
      save_coding_line(source: 'fiscal')
    end

    # Fiscal corrects the invoice's own fields too. What changed goes in the
    # history, since these are the approved values.
    def save_invoice_fields
      permitted = params.fetch(:invoice, {}).permit(*Aim::FiscalRecord::INVOICE_FIELDS).to_h
      return if permitted.empty?

      @invoice.assign_attributes(tidy(permitted))
      changed = @invoice.changed
      return if changed.empty?

      @invoice.save!
      restamp
      @invoice.events.create!(action: 'fiscal', actor: current_user_email,
                              note: "Fiscal changed #{changed.map { |field| helpers.aim_field_label(field) }.to_sentence}")
    end

    # The stamp shows the invoice date, so a change makes a new one.
    def restamp
      @record.update!(stamped_at: nil, stamp_error: nil)
      Aim::StampApprovedJob.perform_later(@invoice.id)
    end

    def tidy(values) = values.transform_values { |value| value.to_s.strip.presence }
  end
end
