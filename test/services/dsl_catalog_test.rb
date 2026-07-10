# frozen_string_literal: true

require "test_helper"

class DslCatalogTest < ActiveSupport::TestCase
  test "loads every repository DSL into grouped and ungrouped collections" do
    expected_count = Rails.root.glob("dsl/*.rb").size

    assert_equal expected_count, DslCatalog.entries.size
    assert_equal expected_count, DslCatalog.grouped.values.flatten.size + DslCatalog.ungrouped.size
    assert_includes DslCatalog.grouped.keys, "chart_of_accounts"
  end

  test "only resolves known slugs" do
    assert_equal "employees", DslCatalog.find!("employees").slug
    assert_raises(ActiveRecord::RecordNotFound) { DslCatalog.find!("../Gemfile") }
  end

  test "exposes workflow enabled state" do
    assert_predicate DslCatalog.find!("revenue_sources"), :enabled?
    assert_not_predicate DslCatalog.find!("parking_lots"), :enabled?
  end
end
