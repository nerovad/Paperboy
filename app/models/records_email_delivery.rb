# frozen_string_literal: true

# One Records email that went out: which table, to whom, how many rows, and
# who or which rule sent it. Written for every send from the grid's Email
# dialog and every run of a RecordsEmailRule, and kept when the rule is
# deleted, so "were they told?" still has an answer.
class RecordsEmailDelivery < ApplicationRecord
  belongs_to :rule, class_name: 'RecordsEmailRule', foreign_key: :records_email_rule_id, optional: true,
                    inverse_of: :deliveries

  scope :for_table, ->(slug) { where(table_slug: slug) }
  scope :recent, -> { order(created_at: :desc, id: :desc) }

  def recipient_list = RecordsEmailRecipients.parse(recipients)
end
