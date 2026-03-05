class OrgPermission < ApplicationRecord
  validates :permission_type, presence: true, inclusion: { in: %w[dropdown form] }
  validates :permission_key, presence: true

  # Returns the most specific org level label for display
  def org_level_label
    if unit_id.present?
      "Unit"
    elsif department_id.present?
      "Department"
    elsif division_id.present?
      "Division"
    elsif agency_id.present?
      "Agency"
    else
      "Unknown"
    end
  end
end
