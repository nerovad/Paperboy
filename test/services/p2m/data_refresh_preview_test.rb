# frozen_string_literal: true

require 'test_helper'

module P2m
  class DataRefreshPreviewTest < ActiveSupport::TestCase
    test 'previews queued OMS numbers for the refresh page' do
      Dir.mktmpdir do |directory|
        queue = Pathname.new(directory).join('sent').tap(&:mkpath)
        queue.join('Mail.dat_51786524.zip').write('marker')
        queue.join('Mail.dat_51671902.zip').write('marker')
        entry = Struct.new(:slug, :key, :config) do
          def enabled? = true
        end.new(
          'oms', 'Oms',
          { orchestration: { root_path: directory, sent_path: 'sent', queue: { path: :sent_path } } }
        )

        DslCatalog.stub(:grouped, { 'print_2_mail_billing_data' => [entry] }) do
          entries = DataRefresh.preview_entries

          assert_equal ['OMS 51671902', 'OMS 51786524'], entries.map(&:key)
          assert_equal %w[oms oms], entries.map(&:slug)
        end
      end
    end
  end
end
