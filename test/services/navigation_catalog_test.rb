# frozen_string_literal: true

require 'test_helper'

# NavigationCatalog is the system-wide half of the command palette: everywhere
# a person can be sent, gathered from sidebars they may not currently be
# looking at. What it must never do is offer a door the sidebar that owns it
# would have hidden, so most of this is about the filtering.
#
# The permission questions all belong to the view, so the subject here is
# handed a stand-in that answers them from a plain hash. The paths come from
# config/routes.rb either way.
class NavigationCatalogTest < ActiveSupport::TestCase
  class FakeView
    def initialize(apps:, features: [], dropdown: [], tools: [], billing: [], aim_queues: false)
      @apps = apps
      @features = features
      @dropdown = dropdown
      @tools = tools
      @billing = billing
      @aim_queues = aim_queues
    end

    attr_reader :apps

    def paperboy_apps = apps
    def can_use_app_feature?(app_key, feature_key) = @features.include?("#{app_key}:#{feature_key}")
    def system_admin? = false
    def current_user_dropdown_permissions = @dropdown
    def records_portal_path = nil
    def available_authorization_consoles = []
    def admin_tools_links = @tools
    def billing_sidebar_items = @billing
    def aim_queue_access? = @aim_queues
  end

  def catalog(**options)
    NavigationCatalog.new(FakeView.new(**options))
  end

  def labels(subject) = subject.destinations.map(&:label)

  test 'every app the switcher offers gets a row of its own' do
    subject = catalog(apps: [{ key: 'paperboy', label: 'Paperboy', path: '/' },
                             { key: 'billing', label: 'Billing', path: '/billing' }])

    assert_equal %w[Paperboy Billing], labels(subject)
    assert_equal ['Application'], subject.destinations.map(&:app).uniq
  end

  # The app switcher is already filtered by ACL > Applications, so an app the
  # viewer cannot open never reaches this list — and neither does anything
  # inside it, however generously its own sidebar would have answered.
  test 'an app the switcher left out contributes nothing' do
    subject = catalog(apps: [{ key: 'paperboy', label: 'Paperboy', path: '/' }],
                      features: ['digital_asset_management:collections'],
                      billing: [{ label: 'View Billing', path: '/billing/dashboard', page: true }],
                      aim_queues: true)

    assert_equal ['Paperboy'], labels(subject)
  end

  test 'a sidebar link is offered only with the feature grant behind it' do
    apps = [{ key: 'digital_asset_management', label: 'Digital Asset Management',
              path: '/digital_asset_management' }]

    assert_equal ['Digital Asset Management'], labels(catalog(apps: apps))

    subject = catalog(apps: apps, features: ['digital_asset_management:collections'])

    assert_equal ['Digital Asset Management', 'Collections'], labels(subject)
    assert_equal digital_asset_management_collections_path, subject.destinations.last.path
  end

  test 'a destination is filed under the app it belongs to' do
    subject = catalog(apps: [{ key: 'p2m', label: 'Print 2 Mail', path: '/p2m' }],
                      features: ['p2m:oms_status'])

    assert_equal ['Print 2 Mail'], subject.destinations.map(&:app).last(1)
    assert_equal 'OMS Status', labels(subject).last
  end

  test 'the apps a person types by their initials answer to them' do
    subject = catalog(apps: [{ key: 'coa', label: 'Chart of Accounts', path: '/coa' }])

    assert_includes subject.destinations.first.keywords, 'coa'
  end

  test 'Paperboy offers the profile menu, one entry per dropdown grant' do
    subject = catalog(apps: [{ key: 'paperboy', label: 'Paperboy', path: '/' }],
                      dropdown: %w[inbox help])

    assert_equal %w[Paperboy Inbox Help], labels(subject)
  end

  test 'every Chart of Accounts table is a destination of its own' do
    subject = catalog(apps: [{ key: 'coa', label: 'Chart of Accounts', path: '/coa' }],
                      features: ['coa:billing_lookup', 'coa:funds'])

    assert_equal ['Chart of Accounts', 'Billing Lookup', 'Fund'], labels(subject)
    assert_equal coa_funds_path, subject.destinations.last.path
  end

  test 'AIM queues follow the same grant the AIM sidebar checks' do
    apps = [{ key: 'aim', label: 'Automated Invoice Management', path: '/aim' }]

    assert_equal ['Automated Invoice Management'], labels(catalog(apps: apps))
    assert_includes labels(catalog(apps: apps, aim_queues: true)), 'Action Needed'
  end

  test 'Billing offers its screens and not its operations' do
    items = [{ label: 'View Billing', path: '/billing/dashboard', page: true },
             { label: 'Run Billing', path: '/billing/monthly_report/run' }]
    subject = catalog(apps: [{ key: 'billing', label: 'Billing', path: '/billing' }], billing: items)

    assert_equal ['Billing', 'View Billing'], labels(subject)
  end

  test 'Admin Tools screens carry their blurb as words to match on' do
    tools = [{ key: 'acl', label: 'ACL', blurb: 'Groups, members and permissions.', path: '/acl' }]
    subject = catalog(apps: [{ key: 'admin_tools', label: 'Admin Tools', path: '/admin_tools' }], tools: tools)

    assert_equal ['Admin Tools', 'ACL'], labels(subject)
    assert_equal 'Groups, members and permissions.', subject.destinations.last.keywords
  end

  test 'the Production bookmarks are marked external so they open in a new tab' do
    subject = catalog(apps: [{ key: 'print_production', label: 'Production', path: '/production' }])
    asana = subject.destinations.find { |destination| destination.label == 'Asana' }

    assert asana.external
    assert_equal 'https://app.asana.com/', asana.path
    assert_not subject.destinations.first.external
  end

  test 'Data Runner offers every DSL by name' do
    entry = DslCatalog::Entry.new(key: 'Vendor Load', slug: 'vendor_load', path: nil,
                                  config: { group: { name: 'Finance' } })

    DslCatalog.stub(:entries, [entry]) do
      subject = catalog(apps: [{ key: 'data_runner', label: 'Data Runner', path: '/data_runner' }])

      assert_equal ['Data Runner', 'Vendor Load'], labels(subject)
      assert_equal data_runner_dsl_path('vendor_load'), subject.destinations.last.path
    end
  end
end
