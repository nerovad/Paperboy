# frozen_string_literal: true

module Dam
  # A starred asset or collection, per employee. Drives the top half of the
  # Dashboard.
  class Favorite < ApplicationRecord
    self.record_timestamps = false

    belongs_to :favoritable, polymorphic: true

    validates :employee_id, presence: true
    validates :favoritable_id, uniqueness: { scope: %i[employee_id favoritable_type] }

    scope :for_employee, ->(employee_id) { where(employee_id: employee_id.to_s) }
    scope :newest_first, -> { order(created_at: :desc) }

    # Star or unstar in one call, since the UI is a single toggle button.
    # Returns the new row when it was starred, nil when it was unstarred.
    def self.toggle!(employee_id:, subject:)
      existing = find_by(employee_id: employee_id.to_s, favoritable_type: subject.class.name, favoritable_id: subject.id)
      return nil if existing&.destroy

      create!(employee_id: employee_id.to_s, favoritable_type: subject.class.name,
              favoritable_id: subject.id, created_at: Time.current)
    end

    def self.favorited?(employee_id:, subject:)
      exists?(employee_id: employee_id.to_s, favoritable_type: subject.class.name, favoritable_id: subject.id)
    end

    # Ids of every favourited record of one class, so a grid can mark its stars
    # with a single query instead of one per row.
    def self.ids_for(employee_id:, type:)
      for_employee(employee_id).where(favoritable_type: type).pluck(:favoritable_id).to_set
    end
  end
end
