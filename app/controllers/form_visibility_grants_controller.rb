# frozen_string_literal: true

# Admin screen for submission visibility grants: lets every member of a group
# see submissions of a chosen form that aren't their own — in the Inbox, on the
# Submissions page, or both, and optionally only within one agency, division,
# department or unit. Keyed by model class name, so it covers both dynamic
# form-builder forms and legacy hand-written ones.
class FormVisibilityGrantsController < ApplicationController
  # Reached only from the Manage Forms screen, so it rides on that tab's grant
  # rather than carrying an ACL key of its own.
  before_action -> { require_admin_tab('manage_forms') }

  def index
    @form_types = Forms::VisibilityGrant.form_type_catalog
    @form_labels = @form_types.to_h { |ft| [ft[:class_name], ft[:label]] }
    @grants = Forms::VisibilityGrant.for_group(Group.pluck(:GroupID))
                                    .includes(:group)
                                    .sort_by { |g| [g.form_label(@form_labels).to_s.downcase, g.group&.group_name.to_s.downcase] }
    @groups = Group.order(:group_name)
  end

  def create
    grant = Forms::VisibilityGrant.new(grant_attributes)

    if grant.form_type.blank? || grant.group_id.blank?
      redirect_to form_visibility_grants_path, alert: 'Pick a form and a group.'
    elsif grant.save
      redirect_to form_visibility_grants_path, notice: 'Visibility grant added.'
    else
      redirect_to form_visibility_grants_path,
                  alert: grant.errors.full_messages.to_sentence.presence || 'Could not add grant.'
    end
  end

  def destroy
    grant = Forms::VisibilityGrant.find(params[:id])
    grant.destroy
    redirect_to form_visibility_grants_path, notice: 'Visibility grant removed.'
  end

  private

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
