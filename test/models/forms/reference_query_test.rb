# frozen_string_literal: true

require 'test_helper'

# Reading what somebody typed into a search box as a reference number. The
# quick search offers a "go to this submission" row on the strength of this,
# and SubmissionsController#lookup resolves it, so the two questions asked
# here are: is this a reference at all, and which form does its prefix name.
module Forms
  class ReferenceQueryTest < ActiveSupport::TestCase
    test 'a full reference parses into its prefix and id' do
      assert_equal({ prefix: 'PLS', id: '845' }, Reference.parse_query('PLS-845'))
    end

    test 'case and surrounding space do not matter' do
      assert_equal({ prefix: 'PLS', id: '845' }, Reference.parse_query('  pls-845 '))
    end

    # Nobody reaches for the dash when they are typing fast, and the prefix is
    # letters and the id digits, so there is nothing ambiguous to lose by it.
    test 'the dash is optional' do
      assert_equal({ prefix: 'PLS', id: '845' }, Reference.parse_query('pls845'))
    end

    test 'a bare id parses with no prefix' do
      assert_equal({ prefix: nil, id: '845' }, Reference.parse_query('845'))
    end

    # Without digits there is no record being named — and a search box that
    # treated every two-letter word as a reference would offer the row
    # constantly on the way to somewhere else.
    test 'anything without an id is not a reference' do
      assert_nil Reference.parse_query('PLS')
      assert_nil Reference.parse_query('leave of absence')
      assert_nil Reference.parse_query('who am i')
      assert_nil Reference.parse_query('')
      assert_nil Reference.parse_query(nil)
    end

    test 'a prefix stuck to more than a number is not a reference' do
      assert_nil Reference.parse_query('form 845 request')
      assert_nil Reference.parse_query('PLS-845-2')
    end

    test 'a prefix resolves to the class whose forms wear it' do
      map = { 'ParkingLotSubmission' => 'PLS', 'ProbationTransferRequest' => 'PTR' }

      assert_equal 'ParkingLotSubmission', Reference.class_name_for_prefix('PLS', map)
      assert_equal 'ProbationTransferRequest', Reference.class_name_for_prefix('ptr', map)
    end

    test 'a prefix no form uses resolves to nothing' do
      map = { 'ParkingLotSubmission' => 'PLS' }

      assert_nil Reference.class_name_for_prefix('ZZZ', map)
      assert_nil Reference.class_name_for_prefix(nil, map)
      assert_nil Reference.class_name_for_prefix('', map)
    end
  end
end
