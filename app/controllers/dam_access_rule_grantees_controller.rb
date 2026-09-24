# frozen_string_literal: true

# Add and remove the people a DAM access rule opens its assets to: a group,
# one employee, or everyone inside an org level. Both actions return to the
# rule's edit page, where the grantees are listed.
class DamAccessRuleGranteesController < ApplicationController
  before_action -> { require_admin_tab('acl') }
  before_action :set_rule

  def create
    grantee = @rule.grantees.build(grantee_attributes)

    if grantee.save
      redirect_to edit_dam_access_rule_path(@rule), notice: "Added #{grantee.label}."
    else
      redirect_to edit_dam_access_rule_path(@rule),
                  alert: grantee.errors.full_messages.to_sentence.presence || 'Could not add that.'
    end
  end

  def destroy
    grantee = @rule.grantees.find(params[:id])
    grantee.destroy
    redirect_to edit_dam_access_rule_path(@rule), notice: "Removed #{grantee.label}."
  end

  private

  def set_rule
    @rule = Dam::AccessRule.find(params[:dam_access_rule_id])
  end

  # The org selects post under the shared cascade's names (agency, division,
  # …); the columns carry the _id suffix.
  def grantee_attributes
    permitted = params.permit(:grantee_type, :group_id, :employee_id, :agency, :division, :department, :unit)
    type = permitted[:grantee_type].to_s

    attributes = { grantee_type: type }
    case type
    when 'group' then attributes[:group_id] = permitted[:group_id].presence
    when 'employee' then attributes[:employee_id] = permitted[:employee_id]
    when 'org'
      Dam::AccessRuleGrantee::ORG_LEVELS.each { |level| attributes[:"#{level}_id"] = permitted[level] }
    end
    attributes
  end
end
