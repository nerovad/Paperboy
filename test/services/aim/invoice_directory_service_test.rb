# frozen_string_literal: true

require 'test_helper'

module Aim
  # Where AIM's files are, as this server sees them. AIM v2: no queue folders,
  # only the store and the places a copy goes at the end.
  class InvoiceDirectoryServiceTest < ActiveSupport::TestCase
    MANAGED = (InvoiceDirectoryService::PATH_ENV.values + %w[AIM_LINUX_QUEUE_BASE_PATH AIM_WINDOWS_QUEUE_BASE_PATH]).freeze

    setup do
      @old_env = MANAGED.to_h { |key| [key, ENV.fetch(key, nil)] }
      MANAGED.each { |key| ENV.delete(key) }
      ENV['AIM_WINDOWS_QUEUE_BASE_PATH'] = 'E:\AIM'
      ENV['AIM_LINUX_QUEUE_BASE_PATH'] = '/mnt/aim-test'
      @service = InvoiceDirectoryService.instance
    end

    teardown do
      @old_env.each { |key, value| value.nil? ? ENV.delete(key) : ENV[key] = value }
    end

    test 'every folder resolves its own configured directory, translated' do
      InvoiceDirectoryService::PATH_ENV.each_value.with_index do |variable, index|
        ENV[variable] = "E:\\AIM\\_BACK_END\\_F#{index}"
      end

      InvoiceDirectoryService::PATH_ENV.each_key.with_index do |key, index|
        assert_equal "/mnt/aim-test/_BACK_END/_F#{index}", @service.path_for(key)
        assert_equal "/mnt/aim-test/_BACK_END/_F#{index}", @service.path_for!(key)
      end
    end

    test 'a folder that is not configured is nil leniently and an error strictly' do
      assert_nil @service.path_for(:store)
      error = assert_raises(Aim::MissingConfiguration) { @service.store_dir }
      assert_match(/AIM_STORE_DIR/, error.message)
    end

    test 'a name that is not a folder is refused' do
      assert_nil @service.path_for(:sql_queue)
      assert_raises(Aim::MissingConfiguration) { @service.path_for!(:sql_queue) }
    end

    test 'paths translate both ways' do
      assert_equal '/mnt/aim-test/_BACK_END/_STORE', @service.translate_path('E:\AIM\_BACK_END\_STORE')
      assert_equal 'E:\AIM\_BACK_END\_STORE', @service.to_windows_path('/mnt/aim-test/_BACK_END/_STORE')
    end

    test 'only a leading base is swapped, matched without regard to case on the share side' do
      assert_equal '/mnt/aim-test/_STORE', @service.translate_path('e:\\aim\\_STORE')
      assert_equal 'F:/Copy/E:/AIM/x', @service.translate_path('F:\\Copy\\E:\\AIM\\x')
      assert_equal '\\backup\\mnt\\aim-test\\x', @service.to_windows_path('/backup/mnt/aim-test/x')
    end

    test 'a UNC share base translates whatever case the path spells it in' do
      ENV['AIM_WINDOWS_QUEUE_BASE_PATH'] = '\\\\gsa-fs01\\AIM'

      assert_equal '/mnt/aim-test/_BACK_END', @service.translate_path('\\\\GSA-FS01\\aim\\_BACK_END')
      assert_equal '\\\\gsa-fs01\\AIM\\_BACK_END', @service.to_windows_path('/mnt/aim-test/_BACK_END')
    end

    test 'an invoice knows its store folder and pdf' do
      ENV['AIM_STORE_DIR'] = 'E:\AIM\_BACK_END\_STORE'
      invoice = Aim::Invoice.new(batch_id: '4601.X', state: 'received')

      assert_equal '/mnt/aim-test/_BACK_END/_STORE/4601.X', invoice.store_dir
      assert_equal '/mnt/aim-test/_BACK_END/_STORE/4601.X/4601.X.pdf', invoice.pdf_path
    end
  end
end
