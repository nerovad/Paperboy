# frozen_string_literal: true

# Add and remove submission visibility grants — the rows behind the Submission
# Visibility section of a group's ACL page (acl/_submission_visibility). A grant
# lets every member of a group see submissions of a chosen form that aren't
# their own, in the Inbox, on the Submissions page or both, and optionally only
# within one agency, division, department or unit.
#
# There is no index: the grants are listed on the ACL page they belong to, which
# is also where both actions return.
class FormVisibilityGrantsController < ApplicationController
  before_action -> { require_admin_tab('acl') }

  def create
    grant = Forms::VisibilityGrant.new(grant_attributes)

    if grant.form_type.blank? || grant.group_id.blank?
      redirect_to grants_path_for(grant.group_id), alert: 'Pick a form.'
    elsif grant.save
      redirect_to grants_path_for(grant.group_id), notice: 'Visibility grant added.'
    else
      redirect_to grants_path_for(grant.group_id),
                  alert: grant.errors.full_messages.to_sentence.presence || 'Could not add grant.'
    end
  end

  def destroy
    grant = Forms::VisibilityGrant.find(params[:id])
    group_id = grant.group_id
    grant.destroy
    redirect_to grants_path_for(group_id), notice: 'Visibility grant removed.'
  end

  private

  # Back to the Submission Visibility section of the group this grant belongs
  # to; the ACL index when the group is unknown (a blank form post).
  def grants_path_for(group_id)
    group_id.present? ? permissions_acl_path(group_id) : acl_index_path
  end

  # The org selects post under the same names the shared cascade partial uses
  # everywhere else (agency, division, …); the columns carry the _id suffix.
  def grant_attributes
    permitted = params.permit(:form_type, :group_id, :applies_to, :agency, :division, :department, :unit)

    {
      form_type: permitted[:form_type].to_s,
      grantee_type: 'group',
      group_id: permitted[:group_id].presence,
      applies_to: permitted[:applies_to].presence || 'both'
    }.merge(Forms::VisibilityGrant::ORG_LEVELS.index_with { |level| permitted[level] }
                                              .transform_keys { |level| :"#{level}_id" })
  end
end
