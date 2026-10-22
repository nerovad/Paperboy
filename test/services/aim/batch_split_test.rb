# frozen_string_literal: true

require 'test_helper'
require 'tmpdir'
require 'prawn'

module Aim
  # A split is cut in Rails (#192): each invoice's pages of the current PDF,
  # a new row for the AI to read, the batch ended as split. All or nothing.
  class BatchSplitTest < ActiveSupport::TestCase
    setup { @store = Dir.mktmpdir }
    teardown { FileUtils.rm_rf(@store) }

    def in_store(&block) = Aim::InvoiceDirectoryService.instance.stub(:store_dir, @store, &block)

    def batch(pages: 3, text: 'page', **attributes)
      row = Aim::Invoice.create!(batch_id: '4601.20260924_090000.Batch-[AB12]', state: 'needs_split', actor: 'aim_worker',
                                 budget_unit: '4601', submitter: 'Jane Doe', assigned_to: 'Jane Doe', assigned_employee_id: 7,
                                 assignment_source: 'folder', source_filename: 'Batch.pdf', page_count: pages, **attributes)
      FileUtils.mkdir_p(row.store_dir)
      Prawn::Document.generate(row.pdf_path) do |doc|
        pages.times do |index|
          doc.start_new_page if index.positive?
          doc.text "#{text} #{index + 1}"
        end
      end
      row
    end

    def plan(*rows, page_count: 3)
      Aim::SplitPlan.new(rows.map { |vendor, number, pages| { vendor_name: vendor, invoice_number: number, pages_text: pages } },
                         page_count: page_count)
    end

    def texts(path) = PDF::Reader.new(path).pages.map { |page| page.text.squish }

    test 'each invoice becomes a row of its own with its pages, and the batch ends as split' do
      in_store do
        parent = batch
        children = Aim::BatchSplit.new(parent, plan(%w[ACME INV-1 1-2], ['', '', '3'])).run!(actor: 'staff@example.test')

        assert_equal ["#{parent.batch_id}_SPLIT_1", "#{parent.batch_id}_SPLIT_2"], children.map(&:batch_id)
        assert_equal([['page 1', 'page 2'], ['page 3']], children.map { |child| texts(child.pdf_path) })
        children.each do |child|
          assert_equal %w[received extract], [child.state, child.command]
          assert_equal [parent.id, false], [child.parent_id, child.split_check]
          assert_equal ['4601', 'Jane Doe', 'Jane Doe', 7, 'folder', 'Batch.pdf'],
                       child.attributes.values_at(*%w[budget_unit submitter assigned_to assigned_employee_id assignment_source source_filename])
          assert child.content_hash.present?
        end
        assert_equal [2, 1], children.map(&:page_count)
        assert_equal %w[ACME INV-1], [children.first.extracted_vendor_name, children.first.invoice_number]

        parent.reload
        assert_equal 'split', parent.state
        assert_nil parent.command
        assert_equal "split into 2: #{children.map(&:batch_id).join(', ')}", parent.events.last.note
        assert_equal 'staff@example.test', parent.events.last.actor
      end
    end

    test 'the current PDF is cut, so changes made in Edit PDF carry through' do
      in_store do
        parent = batch(text: 'edited')
        File.write(File.join(parent.store_dir, "#{parent.batch_id}.base-1.pdf"), 'the original, kept as a version')

        children = Aim::BatchSplit.new(parent, plan(%w[A 1 1], %w[B 2 2-3])).run!(actor: 'staff@example.test')

        assert_equal([['edited 1'], ['edited 2', 'edited 3']], children.map { |child| texts(child.pdf_path) })
      end
    end

    test 'a PDF that is not there splits nothing and leaves nothing behind' do
      in_store do
        parent = batch
        File.delete(parent.pdf_path)

        assert_raises(Aim::BatchSplit::Failed) { Aim::BatchSplit.new(parent, plan(%w[A 1 1], %w[B 2 2-3])).run!(actor: 'x') }
        assert_equal 'needs_split', parent.reload.state
        assert_equal [parent.batch_id], Dir.children(@store)
        assert_equal 1, Aim::Invoice.count
      end
    end

    test 'a row that cannot be written takes its pieces with it' do
      in_store do
        parent = batch
        Aim::Invoice.create!(batch_id: "#{parent.batch_id}_SPLIT_2", state: 'received', actor: 'aim_worker')

        assert_raises(ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique) do
          Aim::BatchSplit.new(parent, plan(%w[A 1 1], %w[B 2 2-3])).run!(actor: 'x')
        end
        assert_equal 'needs_split', parent.reload.state
        assert_not Dir.exist?(File.join(@store, "#{parent.batch_id}_SPLIT_1")), 'no piece is left without its row'
      end
    end

    test 'only a batch waiting to be split is cut' do
      in_store do
        parent = batch(state: 'ready_for_approval')

        assert_raises(Aim::Invoice::IllegalTransition) { Aim::BatchSplit.new(parent, plan(%w[A 1 1], %w[B 2 2-3])).run!(actor: 'x') }
        assert_equal [parent.batch_id], Dir.children(@store)
      end
    end
  end
end
