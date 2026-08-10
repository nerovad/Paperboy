# frozen_string_literal: true

require 'test_helper'

class ApplicationHelperTest < ActionView::TestCase
  self.fixture_table_names = []

  # can_use_app_feature? reads these three. Two of them are controller methods
  # published with helper_method, which the bare view context in this test does
  # not carry, so they are supplied here rather than stubbed.
  attr_writer :granted_features, :granted_dropdowns, :acting_as_system_admin

  def system_admin?
    @acting_as_system_admin.present?
  end

  def current_user_feature_permission_keys
    Array(@granted_features).to_set
  end

  def current_user_dropdown_permissions
    Array(@granted_dropdowns).to_set
  end

  def with_grants(features: [], dropdowns: [])
    self.granted_features = features
    self.granted_dropdowns = dropdowns
    yield
  end

  test 'environment badge labels localhost separately' do
    assert_equal(
      { label: 'LOCALHOST', css_class: 'is-localhost' },
      environment_badge(host: 'localhost', rails_env: 'development')
    )
  end

  test 'environment badge labels development host' do
    assert_equal(
      { label: 'Development', css_class: 'is-development' },
      environment_badge(host: 'dev-gsa-forms', rails_env: 'development')
    )
  end

  test 'environment badge labels staging host' do
    assert_equal(
      { label: 'Stage', css_class: 'is-staging' },
      environment_badge(host: 'stage-gsa-forms', rails_env: 'staging')
    )
  end

  test 'environment badge is hidden in production' do
    assert_nil environment_badge(host: 'gsa-forms', rails_env: 'production')
  end

  test 'a feature grant opens only the button it names' do
    with_grants(features: ['billing:view_reports']) do
      assert can_use_app_feature?('billing', 'view_reports')
      assert_not can_use_app_feature?('billing', 'run_monthly_billing')
    end
  end

  test 'an Admin Tools screen still accepts its legacy dropdown grant' do
    with_grants(dropdowns: ['acl']) do
      assert can_use_app_feature?('admin_tools', 'acl')
      assert_not can_use_app_feature?('admin_tools', 'emulate')
    end
  end

  test 'a dropdown key does not grant a same-named feature in another app' do
    with_grants(dropdowns: ['acl']) do
      assert_not can_use_app_feature?('coa', 'acl')
    end
  end

  test 'system admins hold every feature' do
    self.acting_as_system_admin = true

    assert can_use_app_feature?('billing', 'run_monthly_billing')
  end

  test 'app switcher lists Paperboy first and secondary apps alphabetically' do
    stub(:can_access_app?, true) do
      labels = paperboy_apps.map { |app| app.fetch(:label) }

      assert_equal 'Paperboy', labels.first
      assert_equal labels.drop(1).sort_by(&:downcase), labels.drop(1)
    end
  end
end
