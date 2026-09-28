# frozen_string_literal: true

module Aim
  # Saving an invoice's coding line from a form (item b.2): the review page
  # (a person) and the Fiscal page (Fiscal). Needs @invoice.
  module CodingLineEdits
    extend ActiveSupport::Concern

    private

    def save_coding_line(source:)
      permitted = params.fetch(:coding_line, {}).permit(*Aim::CodingLine::EDITABLE_FIELDS, :encumbrance).to_h
      return if permitted.empty?

      line = @invoice.coding || @invoice.coding_lines.build(line_no: 1)
      line.assign_attributes(permitted.transform_values { |value| value.to_s.strip.presence })
      return unless line.new_record? || line.changed?
      return if line.new_record? && line.blank_coding? && line.amount.blank?

      changed = line.changes.keys & Aim::CodingLine::EDITABLE_FIELDS
      line.assign_attributes(source: source, set_by: current_user_email)
      line.save!
      @invoice.update_column(:coded_at, Time.current) unless @invoice.coded?
      who = source == 'fiscal' ? 'Fiscal' : current_user_email
      @invoice.events.create!(action: 'coding', actor: current_user_email,
                              note: "#{who} set #{changed.map { |f| helpers.aim_coding_field_label(f) }.to_sentence}")
    end
  end
end
