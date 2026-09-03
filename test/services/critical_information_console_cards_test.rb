# frozen_string_literal: true

require 'test_helper'

# The CIR console lists one card per site on the form — including the sites
# nobody covers, which is the whole reason the screen exists.
class CriticalInformationConsoleCardsTest < ActiveSupport::TestCase
  COVERED   = 'TEST CITY-1 FIRST ST.'
  UNCOVERED = 'TEST CITY-2 SECOND ST.'
  RETIRED   = 'RETIRED-1 OLD ST.'

  # Built in memory: these are list-shaping rules, and the cards never load the
  # catalogue themselves — it is handed to them.
  def catalogue
    @catalogue ||= [COVERED, UNCOVERED].each_with_index.map do |name, i|
      CriticalInformationLocation.new(id: i + 1, name: name)
    end
  end

  def rows
    [CriticalInformationAuthorization.new(location: COVERED, employee_id: '111'),
     CriticalInformationAuthorization.new(location: RETIRED, employee_id: '222')]
  end

  def cards(from: rows, **filters)
    CriticalInformationConsoleCards.new(from, catalogue: catalogue, **filters).to_a
  end

  test 'every site on the form gets a card, covered or not' do
    listed = cards

    assert_equal catalogue.size + 1, listed.size, 'expected one card per site, plus the retired location'
    assert_not listed.find { |c| c.location == UNCOVERED }.assigned?
    assert_equal '111', listed.find { |c| c.location == COVERED }.authorization.employee_id
  end

  test 'a row whose location has left the form is flagged, not hidden' do
    card = cards.find { |c| c.location == RETIRED }

    assert_includes card.label, 'no longer on the form'
    assert_equal '222', card.authorization.employee_id
  end

  # The console offers to delete a site from the card, so a card needs the row
  # behind it. A retired card has none — there is nothing left to delete.
  test 'a card carries its location row, except a retired one' do
    listed = cards

    assert_equal 1, listed.find { |c| c.location == COVERED }.location_id
    assert listed.find { |c| c.location == COVERED }.on_the_form?
    assert_not listed.find { |c| c.location == RETIRED }.on_the_form?
    assert_nil listed.find { |c| c.location == RETIRED }.location_id
  end

  test 'the unassigned filter shows only sites nobody covers' do
    listed = cards(assignment: 'unassigned')

    assert_equal catalogue.size - 1, listed.size
    assert(listed.none?(&:assigned?), 'a covered site survived the unassigned filter')
  end

  test 'the assigned filter shows only sites someone covers, retired ones included' do
    listed = cards(assignment: 'assigned')

    assert_equal %w[111 222], listed.map { |c| c.authorization.employee_id }.sort
  end

  test 'filtering by manager drops the sites nobody covers' do
    listed = cards(from: [rows.first], employee_ids: ['111'])

    assert_equal [COVERED], listed.map(&:location)
  end

  # The list used to be built by deleting matches out of the row set while
  # walking the filtered catalogue, so a covered site the location filter
  # excluded was left over and rendered as "no longer on the form".
  test 'a site hidden by the location filter is not mistaken for a retired one' do
    listed = cards(locations: [UNCOVERED])

    assert_equal [UNCOVERED], listed.map(&:location)
    assert(listed.none? { |c| c.label.include?('no longer on the form') })
  end

  test 'the view can still read a card by key' do
    card = cards.first

    assert_equal card.location, card[:location]
    assert_equal card.label, card[:label]
  end
end
