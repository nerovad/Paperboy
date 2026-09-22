# frozen_string_literal: true

require 'test_helper'

# ACL > DAM Access Rules: building a rule and naming who it is for.
class DamAccessRulesControllerTest < ActionController::TestCase
  setup do
    [Dam::AccessRuleGrantee, Dam::AccessRule, Dam::MetadataValue, Dam::MetadataField].each(&:delete_all)
    Dam::MetadataField.create!(key: 'usage_rights', label: 'Usage rights', field_type: 'select',
                               options: ['Internal only', 'Public'].to_json)
  end

  # A rule left behind would hide assets from every other DAM test.
  teardown { [Dam::AccessRuleGrantee, Dam::AccessRule].each(&:delete_all) }

  test 'a rule is saved with its org window and metadata conditions' do
    sign_in

    post :create, params: {
      rule: { name: 'GSA internal', agency_id: 'GSA', can_download: '1' },
      meta: { '0' => { field: 'usage_rights', operator: 'equals', value: 'Internal only' },
              '1' => { field: 'no_such_field', operator: 'equals', value: 'x' } }
    }

    rule = Dam::AccessRule.last

    assert_redirected_to edit_dam_access_rule_path(rule)
    assert_equal 'GSA', rule.agency_id
    assert rule.can_download
    assert_not rule.can_share
    assert_equal [{ 'field' => 'usage_rights', 'operator' => 'equals', 'value' => 'Internal only',
                    'value_to' => '' }], rule.condition_rows
  end

  test 'a rule over the whole library is refused' do
    sign_in

    post :create, params: { rule: { name: 'Everything' } }

    assert_response :unprocessable_entity
    assert_equal 0, Dam::AccessRule.count
  end

  test 'grantees are added and removed on the rule' do
    rule = Dam::AccessRule.create!(name: 'GSA', agency_id: 'GSA')
    @controller = DamAccessRuleGranteesController.new
    sign_in

    post :create, params: { dam_access_rule_id: rule.id, grantee_type: 'group', group_id: 7 }
    post :create, params: { dam_access_rule_id: rule.id, grantee_type: 'org', agency: 'GSA', division: '' }

    assert_equal([%w[group 7], ['org', nil]], rule.grantees.order(:id).map { |g| [g.grantee_type, g.group_id&.to_s] })
    assert_equal({ agency: 'GSA' }, rule.grantees.order(:id).last.org_levels)

    delete :destroy, params: { dam_access_rule_id: rule.id, id: rule.grantees.first.id }

    assert_equal 1, rule.grantees.count
  end

  test 'the rule list and a rule page render, with the access checks' do
    rule = Dam::AccessRule.create!(name: 'GSA internal', agency_id: 'GSA',
                                   condition_rows: [{ field: 'usage_rights', operator: 'equals',
                                                      value: 'Internal only' }])
    rule.grantees.create!(grantee_type: 'employee', employee_id: '1')
    asset = Dam::Asset.create!(title: 'Checked photo', media_type: 'image')
    sign_in

    get :index, params: { check_employee: '1', check_asset: asset.id }

    assert_response :success
    assert_match 'GSA internal', response.body
    assert_match 'Checked photo', response.body

    get :edit, params: { id: rule.id }

    assert_response :success
    assert_match 'Internal only', response.body
  end

  test 'only holders of the ACL tab may touch the rules' do
    sign_in(features: [])

    post :create, params: { rule: { name: 'GSA', agency_id: 'GSA' } }

    assert_equal 0, Dam::AccessRule.count
  end

  private

  def sign_in(features: %w[admin_tools:acl])
    session[:user] = { 'employee_id' => 1, 'email' => 'admin@example.com',
                       'first_name' => 'Test', 'last_name' => 'Admin' }
    keys = features.to_set
    @controller.define_singleton_method(:current_user_group_names) { Set.new }
    @controller.define_singleton_method(:current_user_group_ids) { [] }
    @controller.define_singleton_method(:current_user_org_chain) { {} }
    @controller.define_singleton_method(:current_user_feature_permission_keys) { keys }
    @controller.define_singleton_method(:current_user_dropdown_permissions) { Set.new }
  end
end
