# frozen_string_literal: true

require 'test_helper'

module HsaAdoptionCards
  class LinkedCardsTest < ActiveSupport::TestCase
    ROWS = [
      { 'ID' => 4, 'GroupID' => 7, 'CardType' => 'ADOPTIVE PARENTS' },
      { 'ID' => 9, 'GroupID' => 7, 'CardType' => 'CHILD' },
      { 'ID' => 2, 'GroupID' => 3, 'CardType' => 'CHILD' }
    ].freeze

    # Minitest's stub is not available in this suite, so the class method is
    # swapped by hand and always put back.
    def with_search(rows = ROWS)
      captured = {}
      original = CardSearch.method(:call)
      CardSearch.define_singleton_method(:call) do |params, app_user:|
        captured.merge!(params: params, app_user: app_user)
        rows
      end
      yield captured
    ensure
      CardSearch.define_singleton_method(:call, original)
    end

    test 'searches by the case number and keeps only the row\'s own group' do
      with_search do |captured|
        result = LinkedCards.call({ 'groupId' => 7, 'caseNumber' => '56-97-768', 'lastName' => 'Cross' }, app_user: 'jane@example.com')

        assert_equal({ 'caseNumber' => '56-97-768', 'fuzzy' => 0 }, captured[:params])
        assert_equal 'jane@example.com', captured[:app_user]
        assert_equal([4, 9], result.map { |r| r['ID'] })
      end
    end

    test 'falls back to VEN or A number, then surname and date of birth' do
      with_search do |captured|
        LinkedCards.call({ 'groupId' => 7, 'venOrA' => '17158' }, app_user: 'jane@example.com')
        assert_equal({ 'venOrA' => '17158', 'fuzzy' => 0 }, captured[:params])

        LinkedCards.call({ 'groupId' => 7, 'lastName' => 'Cross', 'dob' => '1956-04-23' }, app_user: 'jane@example.com')
        assert_equal({ 'lastName' => 'Cross', 'dob' => '1956-04-23', 'fuzzy' => 0 }, captured[:params])
      end
    end

    test 'an unlinked card or one with nothing to search by is refused before any SQL' do
      with_search do |captured|
        assert_raises(Error) { LinkedCards.call({ 'groupId' => 0, 'caseNumber' => '1' }, app_user: 'jane@example.com') }
        assert_raises(Error) { LinkedCards.call({ 'groupId' => 7 }, app_user: 'jane@example.com') }
        assert_empty captured
      end
    end
  end
end
