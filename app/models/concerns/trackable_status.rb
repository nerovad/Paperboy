# app/models/concerns/trackable_status.rb
module TrackableStatus
  extend ActiveSupport::Concern

  # Normalized status categories for cross-form reporting
  # Each model must define STATUS_CATEGORIES mapping its statuses to these categories
  VALID_CATEGORIES = %i[pending in_review approved denied cancelled scheduled].freeze

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

    # Returns the normalized category for a given status value
    # Requires the model to define STATUS_CATEGORIES constant
    def status_category_for(status_value)
      return nil if status_value.nil?
      return nil unless const_defined?(:STATUS_CATEGORIES)

      # Normalize status to symbol key
      status_key = if status_value.is_a?(Integer) && const_defined?(:STATUS_MAP)
                     self::STATUS_MAP[status_value]&.to_sym
                   elsif status_value.is_a?(Integer) && defined_enums['status'].present?
                     defined_enums['status'].key(status_value)&.to_sym
                   else
                     status_value.to_s.to_sym
                   end

      self::STATUS_CATEGORIES[status_key]
    end

    # Returns all statuses that belong to a given category
    def statuses_for_category(category)
      return [] unless const_defined?(:STATUS_CATEGORIES)

      self::STATUS_CATEGORIES.select { |_, cat| cat == category.to_sym }.keys
    end

    # Returns hash of category => human-readable label
    def category_labels
      {
        pending: "Pending",
        in_review: "In Review",
        approved: "Approved",
        denied: "Denied",
        cancelled: "Cancelled",
        scheduled: "Scheduled"
      }
    end
  end

  def status_timeline
    status_changes.chronological
  end

  # Returns the normalized category for the current status
  def status_category
    self.class.status_category_for(status)
  end

  # Returns the human-readable label for the current status category
  def status_category_label
    self.class.category_labels[status_category] || "Unknown"
  end

  private

  def record_initial_status
    status_changes.create!(
      from_status: nil,
      to_status: status_label,
      changed_by_id: Current.user&.dig("employee_id")&.to_s,
      changed_by_name: current_user_display_name || name
    )
  end

  def record_status_change
    status_changes.create!(
      from_status: status_label_was,
      to_status: status_label,
      changed_by_id: Current.user&.dig("employee_id")&.to_s,
      changed_by_name: current_user_display_name
    )
  end

  def current_user_display_name
    return nil unless Current.user
    [Current.user["first_name"], Current.user["last_name"]].compact.join(" ").presence
  end

  def status_label_was
    previous_status = status_before_last_save
    self.class.status_label_for(previous_status)
  end
end
