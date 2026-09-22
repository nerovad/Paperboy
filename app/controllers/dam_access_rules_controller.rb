# frozen_string_literal: true

# ACL > DAM Access Rules: which parts of the digital asset library each
# person may see, and what they may do with them. See Dam::AccessRule for
# what a rule means and Dam::Access for how it is enforced.
#
# A rule is created first and given its grantees on its edit page, the way a
# group is created before members are added to it.
class DamAccessRulesController < ApplicationController
  include DamAccessRulesAdmin

  before_action -> { require_admin_tab('acl') }
  before_action :set_rule, only: %i[edit update destroy]
  before_action :load_form_context, only: %i[new create edit update]

  def index
    @rules = Dam::AccessRule.ordered.includes(grantees: :group).to_a
    @fields = Dam::MetadataField.all.index_by(&:key)
    @restricted_counts = @rules.to_h { |rule| [rule.id, rule.restricted_assets(@fields).visible.count] }
    load_employee_check
    load_asset_check
  end

  def new
    @rule = Dam::AccessRule.new(active: true)
  end

  def create
    @rule = Dam::AccessRule.new(rule_params)
    @rule.created_by_id = current_user&.employee_id
    @rule.created_by_name = [current_user&.first_name, current_user&.last_name].compact.join(' ').presence

    if @rule.save
      redirect_to edit_dam_access_rule_path(@rule),
                  notice: 'Rule created. Until you add who it is for, only admins and uploaders see these assets.'
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    load_grantee_context
  end

  def update
    if @rule.update(rule_params)
      redirect_to edit_dam_access_rule_path(@rule), notice: 'Rule saved.'
    else
      load_grantee_context
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @rule.destroy
    redirect_to dam_access_rules_path, notice: "Deleted #{@rule.name}. Its assets are open to everyone again " \
                                               'unless another rule covers them.'
  end

  private

  def set_rule
    @rule = Dam::AccessRule.find(params[:id])
  end

  # The condition builder is the Advanced Search one, so it needs the same
  # field registry the DAM sidebar gives it.
  def load_form_context
    @dam_metadata_fields = Dam::MetadataField.active.ordered
  end

  def load_grantee_context
    @groups = Group.order(:Group_Name)
    @employee_names = employee_names(@rule.grantees.select { |grantee| grantee.grantee_type == 'employee' }
                                                  .map(&:employee_id))
    @employee_results = employee_search(params[:employee_search])
  end

  # The metadata rows post as meta[0][field] …, exactly as Advanced Search's
  # do; the model keeps only rows naming a real field.
  def rule_params
    permitted = params.require(:rule).permit(:name, :description, :active, :can_download, :can_share,
                                             :can_publish, :can_edit, :agency_id, :division_id,
                                             :department_id, :unit_id)
    meta = params.permit(meta: %i[field operator value value_to]).to_h[:meta]
    permitted.merge(condition_rows: meta || {})
  end

  # "Check access" on the index: everything the rules decide about one person.
  def load_employee_check
    id = params[:check_employee].to_s.strip
    return if id.blank?

    access = Dam::Access.for_employee(id)
    @employee_check = {
      id: id,
      name: employee_names([id])[id],
      admin: access.admin?,
      rules: access.held_rules,
      viewable: access.viewable(Dam::Asset.visible).count,
      library: Dam::Asset.visible.count
    }
  end

  # ...and everything they decide about one asset.
  def load_asset_check
    id = params[:check_asset].to_s.strip
    return if id.blank?

    asset = Dam::Asset.find_by(id: id)
    @asset_check = { id: id, asset: asset, rules: asset ? Dam::Access.new(admin: true).restricting_rules(asset) : [] }
  end
end
