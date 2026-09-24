# frozen_string_literal: true

require 'test_helper'
require 'tmpdir'

module Aim
  # The scheduled sync. It runs on every host with Solid Queue -- teammates'
  # machines and servers AIM does not run on among them -- so where AIM is not
  # configured it must do nothing at all. Plan step 5.7b.
  class QueueSyncJobTest < ActiveJob::TestCase
    DirectoryService = Struct.new(:paths) do
      def path_for(queue) = paths[queue.to_sym]
    end

    test 'it is scheduled every ten minutes in every environment' do
      schedule = YAML.load_file(Rails.root.join('config/recurring.yml'), aliases: true)

      %w[production staging development].each do |environment|
        entry = schedule.fetch(environment).fetch('aim_queue_sync')
        assert_equal 'Aim::QueueSyncJob', entry['class']
        assert_equal 'every 10 minutes', entry['schedule']
      end
    end

    test 'with no AIM queue reachable it touches nothing, not even the database' do
      sync = Aim::QueueSync.new(directory_service: DirectoryService.new(paths: {}))

      Aim::Invoice.stub(:group, ->(*) { flunk 'the database was queried on a host without AIM' }) do
        report = sync.call

        assert_empty report.folder_counts
        assert_equal Aim::QueueSync::SYNCED_STATES.size, report.unavailable.size
      end
    end

    test 'it adopts what the share holds' do
      Dir.mktmpdir do |root|
        Dir.mkdir(File.join(root, 'action_needed'))
        Dir.mkdir(File.join(root, 'action_needed', '4601.A'))
        service = DirectoryService.new(paths: { action_needed: File.join(root, 'action_needed') })

        Aim::QueueSync.stub(:new, Aim::QueueSync.new(directory_service: service)) do
          Aim::QueueSyncJob.perform_now
        end
      end

      assert_equal 'action_needed', Aim::Invoice.find_by!(batch_id: '4601.A').state
    end

    test 'a disagreement that survives the sync is logged as a warning' do
      Aim::Invoice.create!(batch_id: '4601.GONE', state: 'action_needed', actor: 'watcher')
      messages = []

      Dir.mktmpdir do |root|
        Dir.mkdir(File.join(root, 'action_needed'))
        service = DirectoryService.new(paths: { action_needed: File.join(root, 'action_needed') })

        Rails.logger.stub(:warn, ->(message) { messages << message }) do
          Aim::QueueSync.stub(:new, Aim::QueueSync.new(directory_service: service)) do
            Aim::QueueSyncJob.perform_now
          end
        end
      end

      assert(messages.any? { _1.include?('still disagree') })
    end
  end
end
