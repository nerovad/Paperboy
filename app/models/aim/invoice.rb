# frozen_string_literal: true

module Aim
  # One invoice, from the moment the watcher mints its batch id. The row is
  # the invoice's state; the files on the share are only its documents.
  class Invoice < Record
    validates :batch_id, :state, presence: true
    validates :batch_id, uniqueness: true
    validates :budget_unit, format: { with: /\A\d{4}\z/ }, allow_nil: true
    validates :claimed_at, presence: true, if: :claimed_by?
    validates :assignment_source, presence: true, if: :assigned_to?
  end
end
