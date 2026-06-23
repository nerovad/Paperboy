# Grants a group full visibility of every submission of a given form type,
# in both the Inbox and the Submissions page (keyed by model class name, so it
# works for both dynamic form-builder forms and legacy hand-written forms like
# CriticalInformationReporting).
#
# In the inbox the grant only surfaces submissions when the holder filters to
# that form type (InboxController#granted_submissions); on the Submissions page
# granted form types are always included (SubmissionsController#submission_scope_for).
class FormVisibilityGrant < ApplicationRecord
  GRANTEE_TYPES = %w[group employee].freeze

  belongs_to :group, foreign_key: :group_id, optional: true

  validates :form_type, presence: true
  validates :grantee_type, inclusion: { in: GRANTEE_TYPES }
  validates :group_id, presence: true, if: -> { grantee_type == 'group' }
  validates :employee_id, presence: true, if: -> { grantee_type == 'employee' }
  validates :form_type, uniqueness: { scope: [:grantee_type, :group_id, :employee_id] }

  scope :for_group, ->(group_id) { where(grantee_type: 'group', group_id: group_id) }

  # Form-type class names the given employee can see every submission of,
  # via either a direct employee grant or membership in a granted group.
  def self.form_types_for(employee_id, group_ids)
    rel = where(grantee_type: 'employee', employee_id: employee_id)
    rel = rel.or(where(grantee_type: 'group', group_id: group_ids)) if group_ids.present?
    rel.distinct.pluck(:form_type)
  end
end
