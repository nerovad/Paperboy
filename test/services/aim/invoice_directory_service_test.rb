# frozen_string_literal: true

require 'test_helper'

module Aim
  class InvoiceDirectoryServiceTest < ActiveSupport::TestCase
    # These tests never read the real environment. Every variable they care
    # about is set here and restored in teardown, so a developer who has not
    # pulled LockBox still gets a green run.
    MANAGED = (InvoiceDirectoryService::PATH_ENV.values +
               %w[AIM_LINUX_QUEUE_BASE_PATH AIM_WINDOWS_QUEUE_BASE_PATH]).freeze

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

    test 'every queue resolves its own configured directory' do
      InvoiceDirectoryService::PATH_ENV.each_value.with_index do |variable, index|
        ENV[variable] = "E:\\AIM\\_BACK_END\\_Q#{index}"
      end

      InvoiceDirectoryService::PATH_ENV.each_value.with_index do |_variable, index|
        expected = "/mnt/aim-test/_BACK_END/_Q#{index}"
        queue = InvoiceDirectoryService::PATH_ENV.keys[index]
        assert_equal expected, @service.path_for(queue)
      end
    end

    # audit M3: path_for and the matching *_dir reader used to disagree, so
    # the sidebar reported "not configured" while writes still succeeded
    # against a guessed folder.
    test 'path_for and the matching reader agree for every queue' do
      InvoiceDirectoryService::PATH_ENV.each_value.with_index do |variable, index|
        ENV[variable] = "E:\\AIM\\_BACK_END\\_Q#{index}"
      end

      readers = {
        ai_queue: :ai_queue_dir, action_needed: :action_needed_dir,
        vendor_review: :vendor_review_dir, manual_processing: :manual_processing_dir,
        batch_split: :batch_split_dir, low_confidence_review: :low_confidence_review_dir,
        sql_queue: :sql_queue_dir, sql_failed: :sql_failed_dir,
        user_approval: :user_approval_dir, rejected: :rejected_dir,
        ready_to_learn: :ready_to_learn_dir, reprocess: :reprocess_dir,
        deleted: :deleted_dir
      }

      readers.each do |queue, reader|
        assert_equal @service.path_for(queue), @service.public_send(reader),
                     "path_for(#{queue.inspect}) and ##{reader} disagree"
      end
    end

    test 'a missing variable raises an error naming the variable' do
      error = assert_raises(MissingConfiguration) { @service.rejected_dir }
      assert_includes error.message, 'AIM_REJECTED_DIR'
    end

    test 'a missing variable never guesses a folder' do
      # The old code fell back to <base>/_REJECTED, which is how invoices
      # ended up somewhere nobody was watching.
      assert_nil @service.path_for(:rejected)
    end

    test 'path_for returns nil for an unknown queue and the strict reader raises' do
      assert_nil @service.path_for(:not_a_queue)
      assert_raises(MissingConfiguration) { @service.path_for!(:not_a_queue) }
    end
  end
end
