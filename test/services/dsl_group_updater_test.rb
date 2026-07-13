# frozen_string_literal: true

require 'test_helper'

class DslGroupUpdaterTest < ActiveSupport::TestCase
  test 'adds and removes group membership across DSL files' do
    originals = DslCatalog.entries.to_h { |entry| [entry.path, entry.path.read] }
    grouped = DslCatalog.find!('activities')
    ungrouped = DslCatalog.find!('employees')

    DslGroupUpdater.new(group: 'chart_of_accounts', slugs: ['employees']).update!

    assert_no_match(/group: \{\n      name: 'chart_of_accounts'\n    \},/, grouped.path.read)
    assert_match(/group: \{\n      name: 'chart_of_accounts'\n    \},\n    source: \{/, ungrouped.path.read)
  ensure
    originals&.each { |path, source| path.write(source) }
    DslCatalog.reload!
  end

  test 'rejects unknown DSL slugs' do
    assert_raises(ActiveRecord::RecordNotFound) do
      DslGroupUpdater.new(group: 'chart_of_accounts', slugs: ['missing']).update!
    end
  end

  test 'adds a DSL to a new valid group' do
    originals = DslCatalog.entries.to_h { |entry| [entry.path, entry.path.read] }
    employee = DslCatalog.find!('employees')

    DslGroupUpdater.new(group: 'finance_reporting', slugs: ['employees']).update!

    assert_match(/group: \{\n      name: 'finance_reporting'\n    \},\n    source: \{/, employee.path.read)
  ensure
    originals&.each { |path, source| path.write(source) }
    DslCatalog.reload!
  end

  test 'renames every DSL in a group' do
    originals = DslCatalog.entries.to_h { |entry| [entry.path, entry.path.read] }

    renamed = DslGroupUpdater.new(group: 'chart_of_accounts', slugs: []).rename!('Finance Reporting')

    assert_equal 'finance_reporting', renamed
    assert(DslCatalog.entries.select { |entry| entry.group == 'finance_reporting' }.many?)
    assert_empty(DslCatalog.entries.select { |entry| entry.group == 'chart_of_accounts' })
  ensure
    originals&.each { |path, source| path.write(source) }
    DslCatalog.reload!
  end

  test 'does not rename a group to an existing DSL name' do
    originals = DslCatalog.entries.to_h { |entry| [entry.path, entry.path.read] }

    error = assert_raises(DslGroupUpdater::DslNameConflict) do
      DslGroupUpdater.new(group: 'chart_of_accounts', slugs: []).rename!('Employees')
    end

    assert_equal 'Employees', error.message

    current = DslCatalog.entries.to_h { |entry| [entry.path, entry.path.read] }

    assert_equal originals, current
  ensure
    originals&.each { |path, source| path.write(source) }
    DslCatalog.reload!
  end

  test 'deletes a group from every associated DSL' do
    originals = DslCatalog.entries.to_h { |entry| [entry.path, entry.path.read] }

    DslGroupUpdater.new(group: 'chart_of_accounts', slugs: []).delete!

    assert_empty(DslCatalog.entries.select { |entry| entry.group == 'chart_of_accounts' })
  ensure
    originals&.each { |path, source| path.write(source) }
    DslCatalog.reload!
  end
end
