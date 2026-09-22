# frozen_string_literal: true

require 'test_helper'
require 'tmpdir'

module Aim
  # The database has to say what the share says. Until the workers write their
  # own rows in 5.6, this is the only thing that makes that true -- and at
  # go-live it is what carries the in-flight invoices over. Plan step 5.5.
  # rubocop:disable Metrics/ClassLength
  class QueueSyncTest < ActiveSupport::TestCase
    DirectoryService = Struct.new(:paths) do
      def path_for(queue) = paths[queue.to_sym]
    end

    def with_queues(**queues)
      Dir.mktmpdir do |root|
        paths = queues.to_h do |state, batch_ids|
          path = File.join(root, state.to_s)
          Dir.mkdir(path)
          Array(batch_ids).each { |batch_id| Dir.mkdir(File.join(path, batch_id)) }
          [state, path]
        end

        yield Aim::QueueSync.new(directory_service: DirectoryService.new(paths: paths)), paths
      end
    end

    test 'a folder with no row is adopted where it sits' do
      with_queues(action_needed: %w[4601.A 4601.B], vendor_review: %w[4601.C]) do |sync|
        report = sync.call

        assert_equal 3, report.adopted
        assert_equal %w[action_needed action_needed vendor_review],
                     Aim::Invoice.order(:batch_id).pluck(:state)
        actors = Aim::Invoice.order(:batch_id).map { _1.events.last.actor }

        assert_equal %w[queue_sync queue_sync queue_sync], actors
      end
    end

    test 'the counts from the database match the counts from the folders' do
      with_queues(ai_queue: %w[4601.A], action_needed: %w[4601.B 4601.C], sql_queue: []) do |sync|
        report = sync.call

        assert_predicate report, :agreed?
        assert_empty report.disagreements
        assert_equal({ ai_queue: 1, action_needed: 2, sql_queue: 0 }, report.folder_counts)
        assert_equal 1, report.row_counts[:ai_queue]
        assert_equal 2, report.row_counts[:action_needed]
      end
    end

    test 'running it twice changes nothing the second time' do
      with_queues(action_needed: %w[4601.A 4601.B]) do |sync|
        sync.call
        events_after_first = Aim::InvoiceEvent.count

        report = sync.call

        assert_equal 0, report.changed
        assert_equal events_after_first, Aim::InvoiceEvent.count
      end
    end

    test 'a folder that moved the way the pipeline moves it is recorded as that move' do
      Aim::Invoice.create!(batch_id: '4601.A', state: 'ai_queue', actor: 'watcher')

      with_queues(sql_queue: %w[4601.A]) do |sync|
        report = sync.call

        assert_equal 1, report.moved
        invoice = Aim::Invoice.find_by(batch_id: '4601.A')
        assert_equal 'sql_queue', invoice.state
        event = invoice.events.last

        assert_equal %w[transition ai_queue sql_queue], [event.action, event.from_state, event.to_state]
      end
    end

    test 'a folder someone dragged is followed, and says so' do
      Aim::Invoice.create!(batch_id: '4601.A', state: 'sql_queue', actor: 'watcher')

      with_queues(vendor_review: %w[4601.A]) do |sync|
        report = sync.call

        assert_equal 1, report.jumped
        invoice = Aim::Invoice.find_by(batch_id: '4601.A')
        assert_equal 'vendor_review', invoice.state, 'the share is the truth in this step'

        event = invoice.events.last
        assert_equal %w[sync sql_queue vendor_review], [event.action, event.from_state, event.to_state]
        assert_equal 'folder moved outside the pipeline', event.note
      end
    end

    test 'an invoice already in the user queue is adopted, unsettled type and all' do
      with_queues(user_approval: %w[4601.A]) do |sync|
        report = sync.call

        assert_equal 1, report.adopted
        assert_equal 'user_approval', Aim::Invoice.find_by(batch_id: '4601.A').state
      end
    end

    test 'the rule against moving an untyped invoice to a user still holds' do
      invoice = Aim::Invoice.create!(batch_id: '4601.A', state: 'action_needed', actor: 'watcher')

      assert_raises(ActiveRecord::RecordInvalid) do
        invoice.transition_to!('user_approval', actor: 'reviewer@example.test')
      end
    end

    test 'a row whose folder has gone is counted, not moved' do
      Aim::Invoice.create!(batch_id: '4601.GONE', state: 'action_needed', actor: 'watcher')

      with_queues(action_needed: %w[4601.A]) do |sync|
        report = sync.call

        assert_equal 1, report.missing
        assert_equal 'action_needed', Aim::Invoice.find_by(batch_id: '4601.GONE').state
        assert_not_predicate report, :agreed?
        assert_equal({ action_needed: { folders: 1, rows: 2 } }, report.disagreements)
      end
    end

    test 'a queue that is not configured is reported, not guessed at' do
      with_queues(action_needed: %w[4601.A]) do |sync|
        report = sync.call

        assert_includes report.unavailable, :vendor_review
        assert_not_includes report.unavailable, :action_needed
      end
    end

    test 'a file in a queue is not an invoice' do
      with_queues(action_needed: %w[4601.A]) do |sync, paths|
        File.write(File.join(paths[:action_needed], 'notes.txt'), 'not a folder')

        assert_equal 1, sync.call.adopted
      end
    end

    test 'archived and deleted are not read back from the share' do
      assert_not_includes Aim::QueueSync::SYNCED_STATES, 'archived'
      assert_not_includes Aim::QueueSync::SYNCED_STATES, 'deleted'
      assert_includes Aim::QueueSync::SYNCED_STATES, 'error_queue'
    end

    test 'every state it syncs has a directory Rails can look up' do
      service = Aim::InvoiceDirectoryService.instance
      missing = Aim::QueueSync::SYNCED_STATES.reject { Aim::InvoiceDirectoryService::PATH_ENV.key?(_1.to_sym) }

      assert_empty missing, "no queue path for: #{missing.join(', ')}"
      assert_respond_to service, :path_for
    end
  end
  # rubocop:enable Metrics/ClassLength
end
