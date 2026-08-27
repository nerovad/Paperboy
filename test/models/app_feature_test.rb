# frozen_string_literal: true

require 'test_helper'

# The registry is only useful if its keys match the sidebars they gate: a key
# that drifts does not raise, it silently hides a button (or stops gating one).
class AppFeatureTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test 'permission keys are namespaced by app' do
    assert_equal 'billing:run_monthly_billing', AppFeature.permission_key('billing', 'run_monthly_billing')
  end

  test 'unknown apps declare no features rather than raising' do
    assert_empty AppFeature.for('print_production')
    assert_empty AppFeature.for('no_such_app')
  end

  test 'every Billing sidebar button is grantable' do
    assert_equal Billing::BillingHelper::SIDEBAR_ITEMS.map { |item| item[:key] }.sort,
                 AppFeature.for('billing').map { |feature| feature[:key] }.sort
  end

  test 'every Admin Tools button is grantable' do
    assert_equal AdminToolsHelper::ADMIN_TOOLS.map { |tool| tool[:key] }.sort,
                 AppFeature.for('admin_tools').map { |feature| feature[:key] }.sort
  end

  test 'every Chart of Accounts table is grantable' do
    controller = Coa::BaseController.new
    tables = controller.send(:coa_all_resources).map { |model| controller.send(:coa_feature_key, model) }

    assert_equal tables.sort,
                 AppFeature.for('coa').map { |feature| feature[:key] }
                                      .reject { |key| %w[billing_lookup customer_lookup].include?(key) }.sort
  end

  test 'only Admin Tools carries legacy dropdown keys' do
    assert_equal 'acl', AppFeature.legacy_key('admin_tools', 'acl')
    assert_nil AppFeature.legacy_key('billing', 'view_billing')
  end

  test 'legacy keys are still offered in the ACL dropdown section' do
    dropdown_keys = AclController::DROPDOWN_ITEMS.map { |item| item[:key] }

    AppFeature.for('admin_tools').each do |feature|
      assert_includes dropdown_keys, feature[:legacy_key],
                      "#{feature[:legacy_key]} must stay listed or existing grants become uneditable"
    end
  end

  test 'permission keys for an app are fully qualified' do
    assert_equal %w[data_runner:manage_groups], AppFeature.permission_keys_for('data_runner')
    assert_equal %w[p2m:stage_data p2m:oms_status p2m:data_refresh], AppFeature.permission_keys_for('p2m')
  end
end
