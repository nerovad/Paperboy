# app/helpers/status_helper.rb
module StatusHelper
  # Returns CSS class for a status badge based on the normalized category
  # Accepts either a category symbol or a status string (for backwards compatibility)
  def status_badge_class(status_or_category)
    category = normalize_to_category(status_or_category)

    case category
    when :pending    then "is-pending"
    when :in_review  then "is-in-review"
    when :approved   then "is-approved"
    when :denied     then "is-denied"
    when :cancelled  then "is-cancelled"
    when :scheduled  then "is-scheduled"
    else
      "is-pending"
    end
  end

  # Returns CSS class based on category (use when you have the category directly)
  def category_badge_class(category)
    return "is-pending" if category.nil?

    case category.to_sym
    when :pending    then "is-pending"
    when :in_review  then "is-in-review"
    when :approved   then "is-approved"
    when :denied     then "is-denied"
    when :cancelled  then "is-cancelled"
    when :scheduled  then "is-scheduled"
    else
      "is-pending"
    end
  end

  # Human-readable label for a category
  def category_label(category)
    {
      pending: "Pending",
      in_review: "In Review",
      approved: "Approved",
      denied: "Denied",
      cancelled: "Cancelled",
      scheduled: "Scheduled"
    }[category.to_sym] || "Unknown"
  end

  private

  # Maps legacy status strings to categories for backwards compatibility
  def normalize_to_category(status_or_category)
    return status_or_category if status_or_category.is_a?(Symbol) && TrackableStatus::VALID_CATEGORIES.include?(status_or_category)

    status_string = status_or_category.to_s.downcase

    # Legacy status string mappings
    case status_string
    when "submitted"
      :pending
    when "pending_delegated_approval", "step_1_pending", "step_2_pending",
         "manager_approved", "sent_to_security", "sent_to_hr", "sent_to_next", "in_progress"
      :in_review
    when "approved", "step_1_approved", "step_2_approved", "resolved"
      :approved
    when "denied"
      :denied
    when "cancelled", "canceled"
      :cancelled
    when "scheduled"
      :scheduled
    else
      :pending
    end
  end
end
