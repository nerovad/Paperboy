# frozen_string_literal: true

require 'test_helper'

# Which DSLs a person may open. Data Runner's sidebar is its DSL catalog, so
# this is the gate on the sidebar, the index page, the DSL routes and the
# command palette alike.
class DataRunnerAccessHelperTest < ActiveSupport::TestCase
  # Stands in for the view: DataRunner::AccessHelper asks one question of it,
  # and can_use_app_feature? already answers the ACL lookup elsewhere.
  class Viewer
    include DataRunner::AccessHelper

    def initialize(granted)
      @granted = granted
    end

    def can_use_app_feature?(app_key, feature_key)
      @granted.include?("#{app_key}:#{feature_key}")
    end
  end

  def entry(key:, slug:, group: nil)
    DslCatalog::Entry.new(key: key, slug: slug, path: nil,
                          config: group ? { group: { name: group } } : {})
  end

  def with_catalog(&block)
    entries = [entry(key: 'Vendor Load', slug: 'vendor_load', group: 'finance'),
               entry(key: 'Payroll', slug: 'payroll', group: 'finance'),
               entry(key: 'Orphan', slug: 'orphan')]

    DslCatalog.stub(:entries, entries, &block)
  end

  def viewer(*granted) = Viewer.new(granted)

  test 'the app grant alone opens no DSL' do
    with_catalog do
      assert_empty viewer.permitted_dsls
      assert_not viewer.can_use_dsl?('vendor_load')
    end
  end

  test 'a DSL grant opens that DSL and no other' do
    with_catalog do
      subject = viewer('data_runner:dsl_vendor_load')

      assert subject.can_use_dsl?('vendor_load')
      assert_not subject.can_use_dsl?('payroll')
      assert_equal %w[vendor_load], subject.permitted_dsls.map(&:slug)
    end
  end

  # Somebody who can drag a DSL between groups is administering the catalog;
  # a half-visible drag-and-drop surface would only lie about what is in it.
  test 'managing groups opens the whole catalog' do
    with_catalog do
      subject = viewer('data_runner:manage_groups')

      assert_equal %w[vendor_load payroll orphan], subject.permitted_dsls.map(&:slug)
    end
  end

  test 'the sidebar lists only granted DSLs, grouped as before' do
    with_catalog do
      subject = viewer('data_runner:dsl_payroll', 'data_runner:dsl_orphan')

      assert_equal({ 'finance' => %w[Payroll] },
                   subject.permitted_grouped_dsls.transform_values { |list| list.map(&:key) })
      assert_equal %w[Orphan], subject.permitted_ungrouped_dsls.map(&:key)
    end
  end

  test 'a group nobody is granted into is left out of the sidebar entirely' do
    with_catalog do
      assert_empty viewer('data_runner:dsl_orphan').permitted_grouped_dsls
    end
  end
end
