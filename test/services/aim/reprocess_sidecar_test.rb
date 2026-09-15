# frozen_string_literal: true

require 'test_helper'

module Aim
  class ReprocessSidecarTest < ActiveSupport::TestCase
    test 'resolves the budget unit whichever name the queue recorded it under' do
      {
        'BU' => '4601',
        'bu_number' => '4621',
        'BudgetUnit' => '4641',
        'Budget Unit Number' => '4721'
      }.each do |key, value|
        assert_equal value, ReprocessSidecar.for(key => value)['bu'],
                     "#{key} is a Budget Unit and should reach the worker as one"
      end
    end

    test 'resolves the submitter whichever name the queue recorded it under' do
      ['Submitter', 'submitter_name', 'Submitted by'].each do |key|
        assert_equal 'Dana Reyes', ReprocessSidecar.for(key => 'Dana Reyes')['submitter']
      end
    end

    test 'prefers the payload spelling when a folder carries more than one' do
      sidecar = ReprocessSidecar.for('BU' => '4601', 'Budget Unit Number' => '4721')

      assert_equal '4601', sidecar['bu']
    end

    test 'writes no budget unit rather than an empty one' do
      sidecar = ReprocessSidecar.for('BU' => '', 'InvoiceNumber' => 'INV-1')

      assert_not sidecar.key?('bu'), 'an empty BU would beat the worker\'s own fallback'
    end

    test 'keeps the rest of the metadata and drops the read error' do
      sidecar = ReprocessSidecar.for('VendorName' => 'AIRGAS USA LLC', 'error' => 'Invalid metadata')

      assert_equal 'AIRGAS USA LLC', sidecar['VendorName']
      assert_not sidecar.key?('error')
    end

    test 'an invoice with no metadata at all is still a sidecar' do
      assert_empty ReprocessSidecar.for(nil)
    end
  end
end
