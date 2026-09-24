# frozen_string_literal: true

require 'test_helper'
require 'tmpdir'

module Aim
  # A PDF in, an invoice out: the file in the store under a fresh batch id,
  # one row as received with the extract command. AIM v2.
  class IntakeTest < ActiveSupport::TestCase
    AIM_ENV = %w[AIM_WINDOWS_QUEUE_BASE_PATH AIM_LINUX_QUEUE_BASE_PATH AIM_STORE_DIR].freeze

    setup do
      @tmpdir = Dir.mktmpdir
      @old_env = AIM_ENV.to_h { |key| [key, ENV.fetch(key, nil)] }
      ENV['AIM_WINDOWS_QUEUE_BASE_PATH'] = 'E:\AIM'
      ENV['AIM_LINUX_QUEUE_BASE_PATH'] = @tmpdir
      ENV['AIM_STORE_DIR'] = 'E:\AIM\_BACK_END\_STORE'
    end

    teardown do
      @old_env.each { |key, value| value.nil? ? ENV.delete(key) : ENV[key] = value }
      FileUtils.remove_entry(@tmpdir) if @tmpdir && Dir.exist?(@tmpdir)
    end

    def store(**overrides)
      Aim::Intake.new.store(StringIO.new("%PDF-1.4 test\n"),
                            original_filename: 'Scan: 001?.pdf', budget_unit: '4601', submitter: 'Jane Doe',
                            owner: 'Jane Doe', actor: 'jane@example.com', **overrides)
    end

    test 'mints a v1-format id with the unsafe characters gone' do
      result = store

      assert_match(/\A4601\.\d{8}_\d{6}\.Scan 001-\[[A-Z0-9]{4}\]\z/, result.invoice.batch_id)
    end

    test 'the pdf lands in the store and the row says received, extract' do
      result = store

      assert File.exist?(result.pdf_path)
      assert_equal File.join(@tmpdir, '_BACK_END', '_STORE', result.invoice.batch_id, "#{result.invoice.batch_id}.pdf"),
                   result.pdf_path
      invoice = result.invoice.reload
      assert_equal %w[received extract], [invoice.state, invoice.command]
      assert_equal ['4601', 'Jane Doe', 'Jane Doe', 'upload'],
                   [invoice.budget_unit, invoice.submitter, invoice.assigned_to, invoice.assignment_source]
      assert_equal Digest::SHA256.hexdigest("%PDF-1.4 test\n"), invoice.content_hash
      assert_equal 'jane@example.com', invoice.events.first.actor
    end

    test 'no owner means the shared queue' do
      invoice = store(owner: nil).invoice

      assert_nil invoice.assigned_to
      assert_nil invoice.assignment_source
    end

    test 'a row that cannot be saved leaves no orphan folder behind' do
      assert_raises(ActiveRecord::RecordInvalid) { store(budget_unit: '46') }

      assert_empty Dir.children(File.join(@tmpdir, '_BACK_END', '_STORE'))
    end

    test 'a store that is not configured raises before anything is written' do
      ENV.delete('AIM_STORE_DIR')

      assert_raises(Aim::MissingConfiguration) { store }
      assert_equal 0, Aim::Invoice.count
    end
  end
end
