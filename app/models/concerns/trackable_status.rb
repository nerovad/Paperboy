# app/models/concerns/trackable_status.rb
module TrackableStatus
  extend ActiveSupport::Concern

  included do
    has_many :status_changes, as: :trackable, dependent: :destroy
    after_create :record_initial_status
    after_update :record_status_change, if: :saved_change_to_status?
  end

  # Class method to convert status value to label
  # Works with both enum-based and STATUS_MAP-based models
  class_methods do
    def status_label_for(status_value)
      return nil if status_value.nil?

      # Check if this model uses enum
      if defined_enums['status'].present?
        # For enum, status_value could be string key or integer value
        if status_value.is_a?(Integer)
          # Find the key for this integer value
          key = defined_enums['status'].key(status_value)
          key&.to_s&.humanize || "Unknown"
        else
          status_value.to_s.humanize
        end
      elsif const_defined?(:STATUS_MAP)
        # For STATUS_MAP-based models
        self::STATUS_MAP[status_value]&.humanize || "Unknown"
      else
        status_value.to_s.humanize
      end
    end
  end

  def status_timeline
    status_changes.chronological
  end

  private

  def record_initial_status
    status_changes.create!(
      from_status: nil,
      to_status: status_label,
      changed_by_id: Current.user&.dig("employee_id")&.to_s,
      changed_by_name: Current.user&.dig("name") || name
    )
  end

  def record_status_change
    status_changes.create!(
      from_status: status_label_was,
      to_status: status_label,
      changed_by_id: Current.user&.dig("employee_id")&.to_s,
      changed_by_name: Current.user&.dig("name")
    )
  end

  def status_label_was
    previous_status = status_before_last_save
    self.class.status_label_for(previous_status)
  end
end
