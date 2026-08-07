# frozen_string_literal: true

module Dam
  # The last thing each employee opened, one row per distinct subject.
  #
  # Upserted rather than appended: the Dashboard wants "the ten things you were
  # last working on", and a visit log would have to be grouped and de-duplicated
  # on every render to answer that.
  class RecentView < ApplicationRecord
    self.record_timestamps = false

    belongs_to :viewable, polymorphic: true

    validates :employee_id, presence: true

    scope :for_employee, ->(employee_id) { where(employee_id: employee_id.to_s) }
    scope :newest_first, -> { order(viewed_at: :desc) }
    scope :of_type, ->(type) { where(viewable_type: type) }

    def self.record!(employee_id:, subject:)
      return if employee_id.blank?

      row = find_or_initialize_by(employee_id: employee_id.to_s, viewable_type: subject.class.name,
                                  viewable_id: subject.id)
      row.viewed_at = Time.current
      row.view_count = row.new_record? ? 1 : row.view_count.to_i + 1
      row.save!
    rescue ActiveRecord::RecordNotUnique
      # Two tabs opened the same asset at once. The other one won; either way
      # the row is fresh, and a browsing side effect must never 500 the page.
      nil
    end

    # The subjects themselves, newest first, with the dangling rows of anything
    # since deleted dropped.
    def self.subjects_for(employee_id:, type:, limit: 8)
      for_employee(employee_id).of_type(type).newest_first.limit(limit)
                               .includes(:viewable).filter_map(&:viewable)
    end
  end
end
