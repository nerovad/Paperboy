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
    lookups = Coa::Tables::LOOKUPS.map { |lookup| lookup[:key] }

    assert_equal Coa::Tables::ALL.map { |table| table[:collection] }.sort,
                 AppFeature.for('coa').map { |feature| feature[:key] }
                                      .reject { |key| lookups.include?(key) }.sort
  end

  test 'both Chart of Accounts lookups are grantable' do
    assert_equal %w[billing_lookup customer_lookup],
                 Coa::Tables::LOOKUPS.map { |lookup| lookup[:key] } &
                 AppFeature.for('coa').map { |feature| feature[:key] }
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
    assert_equal %w[p2m:stage_data p2m:oms_status p2m:data_refresh p2m:quality_control p2m:data_reset],
                 AppFeature.permission_keys_for('p2m')

    with_dsls do
      assert_equal %w[data_runner:manage_groups data_runner:dsl_vendor_load data_runner:dsl_orphan],
                   AppFeature.permission_keys_for('data_runner')
    end
  end

  # Data Runner's sidebar is its DSL catalog, so its grants are read from the
  # catalog rather than declared: a DSL dropped into config/data_runner/dsl is
  # grantable without anyone editing this registry.
  test 'every DSL in the catalog is grantable' do
    with_dsls do
      labels = AppFeature.for('data_runner').map { |feature| feature[:label] }

      assert_includes labels, 'Finance: Vendor Load'
      assert_includes labels, 'Orphan'
    end
  end

  test 'a DSL grant is prefixed so it cannot collide with a standing control' do
    assert_equal 'dsl_manage_groups', AppFeature.dsl_key('manage_groups')

    DslCatalog.stub(:entries, [dsl(key: 'Manage Groups', slug: 'manage_groups')]) do
      keys = AppFeature.for('data_runner').map { |feature| feature[:key] }

      assert_equal keys.uniq, keys
      assert_includes keys, 'manage_groups'
      assert_includes keys, 'dsl_manage_groups'
    end
  end

  def dsl(key:, slug:, group: nil)
    DslCatalog::Entry.new(key: key, slug: slug, path: nil,
                          config: group ? { group: { name: group } } : {})
  end

  def with_dsls(&block)
    entries = [dsl(key: 'Vendor Load', slug: 'vendor_load', group: 'finance'),
               dsl(key: 'Orphan', slug: 'orphan')]

    DslCatalog.stub(:entries, entries, &block)
  end
end
