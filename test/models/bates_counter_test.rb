# frozen_string_literal: true

require 'test_helper'

# A Bates counter (#230): its next number, set with its zeros; a run takes
# the numbers, moves the counter on and is logged; a check takes none.
class BatesCounterTest < ActiveSupport::TestCase
  setup { @dir = Dir.mktmpdir }
  teardown { FileUtils.rm_rf(@dir) }

  def pdf(pages)
    path = File.join(@dir, "#{SecureRandom.hex(4)}.pdf")
    Prawn::Document.generate(path) { |doc| (pages - 1).times { doc.start_new_page } }
    path
  end

  def counter(**attributes) = BatesCounter.create!({ name: 'Request 2026-014', start_text: '000100', created_by: 'clerk@example.com' }.merge(attributes))

  test 'the next number is set with its zeros and shown with them' do
    made = counter

    assert_equal [6, 100, '000100'], [made.digits, made.next_number, made.start_text]
    assert_equal([{ 'name' => 'Bates number', 'rows' => ['{number}'] }], made.area_list.map { |area| area.slice('name', 'rows') })
  end

  test 'a run takes one number per page, moves the counter on and is logged' do
    made = counter

    result, run = made.run!([pdf(2), pdf(3)], names: %w[a.pdf b.pdf], by: 'clerk@example.com')

    assert_equal [100, 104], [result.first_number, result.last_number]
    assert_equal 105, made.reload.next_number
    assert_equal ['000100 - 000104', 5, %w[a.pdf b.pdf]], [run.range, run.page_count, run.file_list]
    assert_raises(ActiveRecord::ReadOnlyRecord) { run.update!(created_by: 'someone else') }
  end

  test 'a check takes no numbers' do
    made = counter

    made.preview([pdf(4)])

    assert_equal 100, made.reload.next_number
    assert_equal 0, made.runs.count
  end

  test 'a stamp may name only its own fields' do
    made = BatesCounter.new(name: 'X', created_by: 'x', area_list: [{ 'rows' => ['{number} {approver}'] }])

    assert_not made.valid?
    assert_includes made.errors.full_messages.join, 'Unknown fields: approver'
  end
end
