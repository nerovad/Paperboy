# frozen_string_literal: true

require 'test_helper'

module Aim
  # The approval stamp: a stamped copy beside the store's PDF, which stays as
  # received.
  class ApprovalStampTest < ActiveSupport::TestCase
    setup do
      @store = Dir.mktmpdir
      @invoice = Aim::Invoice.create!(batch_id: '4641.S-1', state: 'approved', actor: 'nobody@example.com',
                                      invoice_date: Date.new(2025, 6, 16))
    end

    teardown { FileUtils.rm_rf(@store) }

    def in_store(&block)
      Aim::InvoiceDirectoryService.instance.stub(:store_dir, @store, &block)
    end

    def write_source(pages: 2)
      FileUtils.mkdir_p(@invoice.store_dir)
      Prawn::Document.generate(@invoice.pdf_path) do |pdf|
        pages.times do |page|
          pdf.start_new_page if page.positive?
          pdf.text "Page #{page + 1}"
        end
      end
    end

    test 'every page carries the received date, invoice date, approver and time' do
      in_store do
        write_source
        original = File.binread(@invoice.pdf_path)
        record = Aim::FiscalRecord.create!(invoice: @invoice)

        Aim::ApprovalStamp.stamp!(record)

        assert_not_nil record.reload.stamped_at
        assert_nil record.stamp_error
        assert_equal original, File.binread(@invoice.pdf_path)
        pages = PDF::Reader.new(Aim::ApprovalStamp.path(@invoice)).pages
        assert_equal 2, pages.size
        pages.each do |page|
          assert_includes page.text, "#{@invoice.created_at.in_time_zone.strftime('%m/%d/%Y')}- Invoice Date:20250616"
          assert_match(%r{nobody@example.com_\d{2}/\d{2}/\d{4}_\d{2}:\d{2}:\d{2}}, page.text)
        end
      end
    end

    test 'a PDF that cannot be stamped is noted, not retried' do
      in_store do
        FileUtils.mkdir_p(@invoice.store_dir)
        File.write(@invoice.pdf_path, 'not a pdf')
        record = Aim::FiscalRecord.create!(invoice: @invoice)

        Aim::ApprovalStamp.stamp!(record)

        assert_nil record.reload.stamped_at
        assert_predicate record.stamp_error, :present?
        assert_not File.exist?(Aim::ApprovalStamp.path(@invoice))
      end
    end

    test 'the job stamps every approved invoice not yet stamped' do
      in_store do
        write_source(pages: 1)
        Aim::StampApprovedJob.perform_now

        assert_not_nil Aim::FiscalRecord.find_by(invoice_id: @invoice.id).stamped_at
        assert File.exist?(Aim::ApprovalStamp.path(@invoice))
      end
    end

    test "the group's layout stamps it; the record names the layout and any safety net it needed (#221)" do
      in_store do
        group = Aim::AgencyGroup.for_agency!('GSA')
        @invoice.update!(agency: 'GSA', budget_unit: '4641')
        layout = Aim::StampLayout.create!(agency_group: group, created_by: 'fiscal@example.com', area_list: [
                                            { 'rows' => ['Approved by {approver}'] },
                                            { 'rows' => ['Budget Unit # {budget_unit}'], 'anchor' => 'top_left',
                                              'x' => -400, 'y' => 20, 'pages' => 'first' }
                                          ])
        write_source(pages: 2)
        record = Aim::FiscalRecord.create!(invoice: @invoice)

        Aim::ApprovalStamp.stamp!(record)

        record.reload
        assert_equal [layout.id, 'page 1: moved back inside the page'], [record.stamp_layout_id, record.stamp_warnings]
        first, second = PDF::Reader.new(Aim::ApprovalStamp.path(@invoice)).pages.map(&:text)
        assert_includes first, 'Approved by nobody@example.com'
        assert_includes first, 'Budget Unit # 4641'
        assert_includes second, 'Approved by nobody@example.com'
        assert_not_includes second, 'Budget Unit #', 'that area is on the first page only'
      end
    end

    test 'a preview stamps nothing on disk' do
      in_store do
        write_source(pages: 1)
        layout = Aim::StampLayout.new(created_by: 'x', area_list: [{ 'rows' => ['PREVIEW {approver}'] }])

        result = Aim::ApprovalStamp.preview(@invoice, layout, values: { 'approver' => 'Martinez, Mark' })

        assert_includes PDF::Reader.new(StringIO.new(result.bytes)).pages.first.text, 'PREVIEW Martinez, Mark'
        assert_not File.exist?(Aim::ApprovalStamp.path(@invoice))
      end
    end
  end
end
