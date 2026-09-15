# frozen_string_literal: true

require 'test_helper'

class RecordsHistoryTest < ActiveSupport::TestCase
  def history = RecordsHistory.new(RegistryTable.find('pcard'))

  def card(first_name = 'Ada')
    PcardInventory.create!(first_name: first_name, last_name: 'Lovelace', monthly_limit: 100)
  end

  test "a row's history reads from when it was added" do
    row = card
    row.update!(first_name: 'Grace')

    assert_equal %w[create update], history.row_entries(row.id).map(&:action)
  end

  test 'a deleted row stays in the history, named as it was' do
    row = card('Grace')
    id = row.id
    row.destroy!

    assert history.row?(id)
    entries = history.row_entries(id)
    assert_equal %w[create destroy], entries.map(&:action)
    assert_equal({ id => 'Grace Lovelace' }, history.row_labels(entries))
  end

  test 'a row that never existed is not part of the table' do
    assert_not history.row?(0)
  end

  test 'the log covers every row of the table and nothing else' do
    first = card('Ada')
    second = card('Grace')
    CreativeJobRequest.create!(job_title: 'Other table', job_id: 'CJR-9').update!(job_title: 'Edited')

    assert_equal [first.id, second.id].sort, history.edits.distinct.pluck(:record_id).sort
    assert_equal ['PcardInventory'], history.edits.distinct.pluck(:record_type)
  end
end
