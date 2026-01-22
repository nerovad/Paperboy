# app/models/status_change.rb
class StatusChange < ApplicationRecord
  belongs_to :trackable, polymorphic: true

  validates :trackable, presence: true
  validates :to_status, presence: true

  scope :chronological, -> { order(created_at: :asc) }
  scope :reverse_chronological, -> { order(created_at: :desc) }
end
