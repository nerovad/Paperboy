# frozen_string_literal: true

require 'test_helper'

class DataRunnerGroupRefreshOrderTest < ActiveSupport::TestCase
  Entry = Data.define(:key, :slug, :config)

  test 'keeps catalog order when nothing waits on another DSL' do
    ordered = DataRunner::GroupRefreshOrder.entries([entry('Bravo'), entry('Alpha')])

    assert_equal %w[Bravo Alpha], ordered.map(&:key)
  end

  test 'places a parent ahead of a child that sorts earlier' do
    entries = [
      entry('A_child', 'Z_parent'),
      entry('M_middle'),
      entry('Z_parent')
    ]
    ordered = DataRunner::GroupRefreshOrder.entries(entries)

    assert_equal %w[M_middle Z_parent A_child], ordered.map(&:key)
  end

  test 'waits for every named parent before a child with more than one' do
    entries = [
      entry('Paperboy_dev_dam_assets', 'Paperboy_dev_dam_storage_locations'),
      entry('Paperboy_dev_dam_collection_assets', %w[Paperboy_dev_dam_assets Paperboy_dev_dam_collections]),
      entry('Paperboy_dev_dam_collections'),
      entry('Paperboy_dev_dam_storage_locations')
    ]
    ordered = DataRunner::GroupRefreshOrder.entries(entries)

    assert_equal %w[
      Paperboy_dev_dam_collections
      Paperboy_dev_dam_storage_locations
      Paperboy_dev_dam_assets
      Paperboy_dev_dam_collection_assets
    ], ordered.map(&:key)
  end

  test 'orders an entry that has no config' do
    plain = Data.define(:key, :slug).new(key: 'OMS 12345678', slug: 'oms')

    assert_equal [plain], DataRunner::GroupRefreshOrder.entries([plain])
  end

  test 'refuses a dependency that is not in this refresh' do
    error = assert_raises(DataRunner::GroupRefreshOrder::Error) do
      DataRunner::GroupRefreshOrder.entries([entry('A_child', 'Missing_parent')])
    end

    assert_equal 'A_child: dependency Missing_parent is not scheduled in this run', error.message
  end

  test 'refuses a dependency cycle and names the DSLs' do
    entries = [entry('Alpha', 'Beta'), entry('Beta', 'Alpha')]
    error = assert_raises(DataRunner::GroupRefreshOrder::Error) do
      DataRunner::GroupRefreshOrder.entries(entries)
    end

    assert_equal 'circular refresh dependency: Alpha, Beta', error.message
  end

  test 'refuses a DSL that depends on itself' do
    error = assert_raises(DataRunner::GroupRefreshOrder::Error) do
      DataRunner::GroupRefreshOrder.entries([entry('Alpha', 'Alpha')])
    end

    assert_equal 'circular refresh dependency: Alpha', error.message
  end

  test 'refuses two entries with the same DSL name' do
    error = assert_raises(DataRunner::GroupRefreshOrder::Error) do
      DataRunner::GroupRefreshOrder.entries([entry('Alpha'), entry('Alpha')])
    end

    assert_equal 'duplicate refresh DSL: Alpha', error.message
  end

  test 'places each catalog dependency before its child' do
    DslCatalog.grouped.each do |group, entries|
      enabled = entries.select(&:enabled?)
      ordered = DataRunner::GroupRefreshOrder.entries(enabled)
      position = ordered.each_with_index.to_h { |item, index| [item.key, index] }

      ordered.each do |item|
        dependencies_of(item).each do |dependency|
          assert_operator position.fetch(dependency), :<, position.fetch(item.key),
                          "#{group}: #{dependency} runs before #{item.key}"
        end
      end
    end
  end

  private

  def entry(key, dependency = nil)
    config = {}
    config[:dependency] = dependency if dependency
    Entry.new(key: key, slug: key.downcase, config: config)
  end

  def dependencies_of(item)
    Array(item.config[:dependency]).map(&:to_s).reject(&:empty?)
  end
end
