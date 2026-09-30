# frozen_string_literal: true

require 'test_helper'
require 'tmpdir'

module Aim
  # An invoice's PDF is read from the store and nowhere else: not through a
  # batch id that names another folder, and not through a symlink in the
  # store that leads out of it.
  class StoredPdfTest < ActiveSupport::TestCase
    AIM_ENV = %w[AIM_WINDOWS_QUEUE_BASE_PATH AIM_LINUX_QUEUE_BASE_PATH AIM_STORE_DIR].freeze

    class Reader
      include Aim::StoredPdf

      public :stored_pdf_path
    end

    setup do
      @tmpdir = Dir.mktmpdir
      @old_env = AIM_ENV.to_h { |key| [key, ENV.fetch(key, nil)] }
      ENV['AIM_WINDOWS_QUEUE_BASE_PATH'] = 'E:\AIM'
      ENV['AIM_LINUX_QUEUE_BASE_PATH'] = @tmpdir
      ENV['AIM_STORE_DIR'] = 'E:\AIM\_STORE'
      @store = File.join(@tmpdir, '_STORE')
      FileUtils.mkdir_p(@store)
    end

    teardown do
      @old_env.each { |key, value| value.nil? ? ENV.delete(key) : ENV[key] = value }
      FileUtils.remove_entry(@tmpdir)
    end

    def invoice(batch_id, state: 'needs_review') = Aim::Invoice.new(batch_id: batch_id, state: state)

    def put(batch_id, name = "#{batch_id}.pdf")
      FileUtils.mkdir_p(File.join(@store, batch_id))
      File.write(File.join(@store, batch_id, name), '%PDF-1.4')
      File.join(@store, batch_id, name)
    end

    test 'the PDF as received, and the stamped copy once approved' do
      received = put('4601.A')
      stamped = put('4601.A', '4601.A.stamped.pdf')

      assert_equal File.realpath(received), Reader.new.stored_pdf_path(invoice('4601.A'))
      assert_equal File.realpath(stamped), Reader.new.stored_pdf_path(invoice('4601.A', state: 'approved'))
    end

    test 'a batch id that is not one folder name finds nothing' do
      put('4601.B')

      ['../_STORE/4601.B', '.hidden', 'a/b', ''].each do |batch_id|
        assert_nil Reader.new.stored_pdf_path(invoice(batch_id)), batch_id
      end
    end

    test 'a symlink out of the store is not followed' do
      outside = File.join(@tmpdir, 'secret.pdf')
      File.write(outside, '%PDF-1.4 secret')
      FileUtils.mkdir_p(File.join(@store, '4601.C'))
      File.symlink(outside, File.join(@store, '4601.C', '4601.C.pdf'))

      assert_nil Reader.new.stored_pdf_path(invoice('4601.C'))
    end

    test 'an unconfigured store finds nothing' do
      ENV.delete('AIM_STORE_DIR')

      assert_nil Reader.new.stored_pdf_path(invoice('4601.D'))
    end
  end
end
