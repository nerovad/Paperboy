# frozen_string_literal: true

require 'test_helper'

class DslGroupUpdaterTest < ActiveSupport::TestCase
  test 'adds and removes group membership across DSL files' do
    originals = DslCatalog.entries.to_h { |entry| [entry.path, entry.path.read] }
    DslGroupUpdater.new(group: 'chart_of_accounts', slugs: ['employees']).update!

    assert_not DslCatalog.find!('activities').path.to_s.include?('/chart_of_accounts/')
    assert_match(%r{/chart_of_accounts/employees\.rb\z}, DslCatalog.find!('employees').path.to_s)
  ensure
    restore_catalog(originals)
    DslCatalog.reload!
  end

  test 'rejects unknown DSL slugs' do
    assert_raises(ActiveRecord::RecordNotFound) do
      DslGroupUpdater.new(group: 'chart_of_accounts', slugs: ['missing']).update!
    end
  end

  test 'adds a DSL to a new valid group' do
    originals = DslCatalog.entries.to_h { |entry| [entry.path, entry.path.read] }
    DslGroupUpdater.new(group: 'finance_reporting', slugs: ['employees']).update!

    assert_match(%r{/finance_reporting/employees\.rb\z}, DslCatalog.find!('employees').path.to_s)
  ensure
    restore_catalog(originals)
    DslCatalog.reload!
  end

  test 'renames every DSL in a group' do
    originals = DslCatalog.entries.to_h { |entry| [entry.path, entry.path.read] }

    renamed = DslGroupUpdater.new(group: 'chart_of_accounts', slugs: []).rename!('Finance Reporting')

    assert_equal 'finance_reporting', renamed
    assert(DslCatalog.entries.select { |entry| entry.group == 'finance_reporting' }.many?)
    assert_empty(DslCatalog.entries.select { |entry| entry.group == 'chart_of_accounts' })
  ensure
    restore_catalog(originals)
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
    restore_catalog(originals)
    DslCatalog.reload!
  end

  test 'deletes a group from every associated DSL' do
    originals = DslCatalog.entries.to_h { |entry| [entry.path, entry.path.read] }

    DslGroupUpdater.new(group: 'chart_of_accounts', slugs: []).delete!

    assert_empty(DslCatalog.entries.select { |entry| entry.group == 'chart_of_accounts' })
  ensure
    restore_catalog(originals)
    DslCatalog.reload!
  end

  private

  def restore_catalog(originals)
    return unless originals

    directory = DslCatalog.send(:directory)
    directory.glob('*/*.rb').each(&:delete)
    originals.each do |path, source|
      path.dirname.mkpath
      path.write(source)
    end
  end
end
