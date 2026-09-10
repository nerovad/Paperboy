# frozen_string_literal: true

require 'test_helper'
require 'tmpdir'

module Aim
  class WorkProviderTest < ActiveSupport::TestCase
    DirectoryService = Struct.new(:paths) do
      def path_for(queue) = paths[queue.to_sym]
    end

    test 'publishes unclaimed invoice folders to authorized AIM viewers' do
      Dir.mktmpdir do |directory|
        invoice = File.join(directory, 'INV-123')
        Dir.mkdir(invoice)
        provider = Aim::WorkProvider.new(directory_service: DirectoryService.new(paths: { action_needed: directory }))

        items = provider.inbox_items(
          viewer: { email: 'reviewer@example.gov', applications: ['aim'] },
          filters: { queue: :action_needed }
        )

        assert_equal ['aim:invoice:action_needed:INV-123'], items.map(&:key)
        assert_equal %i[open claim], items.first.actions
      end
    end

    test 'hides work claimed by another reviewer' do
      Dir.mktmpdir do |directory|
        invoice = File.join(directory, 'INV-456')
        Dir.mkdir(invoice)
        File.write(File.join(invoice, '.claim.json'), { user: 'other@example.gov' }.to_json)
        provider = Aim::WorkProvider.new(directory_service: DirectoryService.new(paths: { action_needed: directory }))

        items = provider.inbox_items(
          viewer: { email: 'reviewer@example.gov', applications: ['aim'] },
          filters: { queue: :action_needed }
        )

        assert_empty items
      end
    end
  end
end
