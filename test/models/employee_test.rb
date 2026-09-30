# frozen_string_literal: true

require 'test_helper'

class EmployeeTest < ActiveSupport::TestCase
  def person(first, last, id: 126_566) = Employee.new(id: id, first_name: first, last_name: last)

  test 'names in each of the app\'s formats' do
    employee = person('Joshua', 'Gannon')

    assert_equal 'Joshua Gannon', employee.full_name
    assert_equal 'Gannon, Joshua', employee.sort_name
    assert_equal 'Gannon, Joshua (126566)', employee.picker_label
    assert_equal 'Joshua Gannon (126566)', employee.name_with_id
  end

  test 'a full name drops blank parts and stray spaces' do
    assert_equal 'Gannon', person(nil, 'Gannon').full_name
    assert_equal 'Joshua Gannon', person(' Joshua ', 'Gannon ').full_name
    assert_equal '', person(nil, nil).full_name
  end

  test 'plucked tuples format the same as records, first name first' do
    assert_equal 'Joshua Gannon', Employee.format_full_name('Joshua', 'Gannon')
    assert_equal 'Gannon, Joshua', Employee.format_sort_name('Joshua', 'Gannon')
    assert_equal 'Gannon, Joshua (7)', Employee.format_picker_label(7, 'Joshua', 'Gannon')
    assert_equal({ value: 7, label: 'Gannon, Joshua (7)', unit: '4641' },
                 Employee.search_option(7, 'Joshua', 'Gannon', '4641'))
  end

  test 'search matches either name, "First Last" or any part of the id, with wildcards escaped' do
    sql = Employee.search(' 50%_off ').to_sql

    assert_includes sql, 'first_name LIKE'
    assert_includes sql, 'last_name LIKE'
    assert_includes sql, 'CAST(id AS VARCHAR(20)) LIKE'
    assert_includes sql, "(first_name + ' ' + last_name) LIKE"
    assert_includes sql, '%50\\%\\_off%'
  end

  test 'a blank search matches nobody without asking the database' do
    assert_empty Employee.search('  ')
    assert_empty Employee.search(nil)
  end

  test 'search narrows an existing relation' do
    sql = Employee.where(id: [1, 2]).search('ann').to_sql

    assert_match(/\[?id\]? IN \(/, sql)
    assert_includes sql, 'first_name LIKE'
  end

  test 'a full id sorts that employee ahead of every other match' do
    sql = Employee.search_ranked(' 102989 ').to_sql

    assert_match(/ORDER BY CASE WHEN id = 102989 THEN 0 ELSE 1 END.*last_name.*first_name/, sql)
  end

  test 'a name search is ordered by surname, with no id ranking' do
    sql = Employee.search_ranked('ann').to_sql

    assert_no_match(/CASE WHEN/, sql)
    assert_match(/ORDER BY .*last_name.*first_name/, sql)
  end

  test 'the exact id comes back ahead of names that sort before it' do
    people = Employee.where.not(last_name: [nil, '']).order(:last_name, :first_name, :id).limit(3).to_a
    skip 'too few employees to test with' if people.size < 3
    last = people.last

    assert_equal last.id, Employee.where(id: people.map(&:id)).in_search_order(last.id.to_s).first.id
    assert_equal people.first.id, Employee.where(id: people.map(&:id)).in_search_order('x').first.id
  end
end
