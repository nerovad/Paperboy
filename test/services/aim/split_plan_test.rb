# frozen_string_literal: true

require 'test_helper'

module Aim
  # A person's split of a batch is only accepted when it makes sense as a
  # whole: every page in exactly one invoice, and at least two invoices.
  # Plan step 5.7c.
  class SplitPlanTest < ActiveSupport::TestCase
    def plan(*rows, page_count: 5)
      Aim::SplitPlan.new(rows.map { |pages| { vendor_name: 'ACME', invoice_number: 'INV', pages_text: pages } },
                         page_count: page_count)
    end

    test 'pages are written the way people write them' do
      assert_equal [1, 2, 3, 5], Aim::SplitPlan.parse_pages('1-3, 5')
      assert_equal [4], Aim::SplitPlan.parse_pages(' 4 ')
      assert_equal [1, 2], Aim::SplitPlan.parse_pages('1 - 2')
    end

    test 'anything else is not a list of pages' do
      ['', 'one', '3-1', '1-', '1,,x', '2.5'].each do |text|
        assert_nil Aim::SplitPlan.parse_pages(text), text.inspect
      end
    end

    test 'pages are shown back compactly' do
      assert_equal '1-3, 5, 7-8', Aim::SplitPlan.page_text([8, 1, 2, 3, 5, 7])
    end

    test 'a sensible split is accepted' do
      assert_predicate plan('1-2', '3-5'), :valid?
    end

    test 'a page in two invoices is refused, naming both' do
      split = plan('1-3', '3-5')

      assert_not split.valid?
      assert_includes split.errors, 'Page 3 is in invoices 1 and 2. A page belongs to one invoice.'
    end

    test 'a page left out is refused' do
      split = plan('1-2', '4-5')

      assert_not split.valid?
      assert_includes split.errors, 'Page 3 is not in any invoice.'
    end

    test 'a page past the end of the PDF is refused' do
      split = plan('1-2', '3-7')

      assert_not split.valid?
      assert_includes split.errors, 'Invoice 2: pages 6-7 are not in this 5-page PDF.'
    end

    test 'one invoice is not a split' do
      split = plan('1-5')

      assert_not split.valid?
      assert_match(/at least two invoices/, split.errors.join)
    end

    test 'a row with no pages is a row the person removed' do
      assert_predicate plan('1-2', '', '3-5'), :valid?
    end

    test 'without a page count the range checks are skipped, not guessed' do
      split = plan('1-2', '3-9', page_count: nil)

      assert_predicate split, :valid?
    end

    test 'the manifest keeps what the AI worker wrote and leaves blanks out' do
      split = Aim::SplitPlan.new([{ vendor_name: 'ACME', invoice_number: 'INV-1', pages_text: '1-2' },
                                  { vendor_name: '', invoice_number: ' ', pages_text: '3' }], page_count: 3)

      manifest = split.manifest('bu' => '4601', 'owner' => 'Jane Doe', 'invoices' => [])

      assert_equal({ 'bu' => '4601', 'owner' => 'Jane Doe',
                     'invoices' => [{ 'vendor_name' => 'ACME', 'invoice_number' => 'INV-1', 'pages' => [1, 2] },
                                    { 'pages' => [3] }] }, manifest)
    end

    # The worker reads these as they are and parses nothing (splitting.py).
    test 'the manifest writes each invoice as sorted, distinct page numbers' do
      split = Aim::SplitPlan.new([{ pages_text: '3, 1-2, 2' }, { pages_text: ' 5 , 4 ' }], page_count: 5)

      pages = split.manifest['invoices'].pluck('pages')

      assert_equal [[1, 2, 3], [4, 5]], pages
      assert(pages.flatten.all?(Integer))
    end

    test 'a manifest is read back as rows, whichever way it wrote its pages' do
      rows = Aim::SplitPlan.rows_from_manifest('invoices' => [
                                                 { 'vendor_name' => 'ACME', 'pages' => [1, 2, 3] },
                                                 { 'invoice_number' => 'INV-2', 'pages' => ['4-5'] }
                                               ])

      assert_equal %w[1-3 4-5], rows.map(&:pages_text)
      assert_equal 'ACME', rows.first.vendor_name
    end
  end
end
