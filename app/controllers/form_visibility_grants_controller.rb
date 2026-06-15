# Admin screen for "full inbox visibility" grants: gives every member of a
# group the ability to see all submissions of a chosen form type in their
# inbox (when they filter to that form type). Keyed by model class name, so it
# covers both dynamic form-builder forms and legacy hand-written forms.
class FormVisibilityGrantsController < ApplicationController
  before_action :require_system_admin

  def index
    @form_types  = form_type_catalog
    @grants_by_type = FormVisibilityGrant.for_group(Group.pluck(:GroupID))
                                         .includes(:group)
                                         .group_by(&:form_type)
    @groups = Group.order(:group_name)
  end

  def create
    form_type = params[:form_type].to_s
    group_id  = params[:group_id].presence

    if form_type.blank? || group_id.blank?
      redirect_to form_visibility_grants_path, alert: "Pick a form and a group." and return
    end

    grant = FormVisibilityGrant.new(form_type: form_type, grantee_type: 'group', group_id: group_id)
    if grant.save
      redirect_to form_visibility_grants_path, notice: "Visibility grant added."
    else
      redirect_to form_visibility_grants_path, alert: grant.errors.full_messages.to_sentence.presence || "Could not add grant."
    end
  end

  def destroy
    grant = FormVisibilityGrant.find(params[:id])
    grant.destroy
    redirect_to form_visibility_grants_path, notice: "Visibility grant removed."
  end

  private

  # Every form type a grant can target: active dynamic templates plus the
  # legacy hand-written forms (kept in sync with InboxHelper::HARDCODED_FORM_TYPES).
  def form_type_catalog
    dynamic = FormTemplate.where(archived: false).order(:name).map do |t|
      { class_name: t.class_name, label: t.name }
    end
    legacy = InboxHelper::HARDCODED_FORM_TYPES.map do |class_name|
      { class_name: class_name, label: class_name.demodulize.titleize }
    end
    (dynamic + legacy).uniq { |f| f[:class_name] }.sort_by { |f| f[:label].to_s.downcase }
  end
end
