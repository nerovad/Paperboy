# frozen_string_literal: true

require 'test_helper'

module P2m
  class DataRefreshTest < ActiveSupport::TestCase # rubocop:disable Metrics/ClassLength
    test 'configures the requested Data Runner groups' do
      labels = DataRefresh::GROUPS.transform_values { |configuration| configuration.fetch(:label) }
      defaults = DataRefresh::GROUPS.transform_values { |configuration| configuration.fetch(:default) }

      assert_equal 'Print 2 Mail Billing Data', labels.fetch('print_2_mail_billing_data')
      assert defaults.fetch('print_2_mail_billing_data')
    end

    test 'refreshes enabled DSLs from selected groups' do
      result = DataRunner::GroupRun.new(group_name: DataRefresh::GROUP_RUN_NAME, total_count: 2)
      calls = []
      runner = lambda do |**arguments|
        calls << arguments
        result
      end
      entry = Struct.new(:slug, :key) do
        def enabled? = true
      end
      catalog = {
        'print_2_mail_billing_data' => [entry.new('oms', 'Oms')]
      }

      DslCatalog.stub(:grouped, catalog) do
        DataRunner::GroupRefresh.stub(:start!, runner) do
          DataRefresh.run!(
            { 'print_2_mail_billing_data' => '1' },
            requested_by: 'employee@example.com'
          )
        end
      end

      assert_equal DataRefresh::GROUP_RUN_NAME, calls.first.fetch(:group)
      assert_equal %w[oms], calls.first.fetch(:entries).map(&:slug)
    end

    test 'describes an orchestrated DSL by its queue path' do
      entry = Struct.new(:key, :slug, :config, :sop) do
        def enabled? = true
      end.new(
        'Oms', 'oms',
        {
          orchestration: {
            root_path: ENV.fetch('P2M_DATARUNNER_ROOT'), sent_path: '00_SentToUSPS',
            queue: { path: :sent_path }
          }
        },
        { reference_title: 'Mail.dat sent to USPS', reference_path: :downloaded_file }
      )
      catalog = { 'print_2_mail_billing_data' => [entry] }

      DslCatalog.stub(:grouped, catalog) do
        dsl = DataRefresh.groups.last.enabled_dsls.first

        assert_equal File.join(ENV.fetch('P2M_DATARUNNER_ROOT'), '00_SentToUSPS'), dsl.location
        assert dsl.script
        assert dsl.current
        assert_equal 'Mail.dat sent to USPS', dsl.sop.fetch(:reference_title)
        assert_equal :downloaded_file, dsl.sop.fetch(:reference_path)
      end
    end

    test 'creates one refresh item for each queued OMS number' do
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
        calls = []
        runner = lambda do |**arguments|
          calls << arguments
          DataRunner::GroupRun.new
        end

        DslCatalog.stub(:grouped, { 'print_2_mail_billing_data' => [entry] }) do
          DataRunner::GroupRefresh.stub(:start!, runner) do
            DataRefresh.run!({ 'print_2_mail_billing_data' => '1' },
                             requested_by: 'employee@example.com')
          end
        end

        assert_equal ['OMS 51671902', 'OMS 51786524'], calls.first.fetch(:entries).map(&:key)
        assert_equal %w[oms oms], calls.first.fetch(:entries).map(&:slug)
      end
    end

    test 'refreshes only selected queued OMS numbers' do
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
        calls = []
        runner = lambda do |**arguments|
          calls << arguments
          DataRunner::GroupRun.new
        end

        DslCatalog.stub(:grouped, { 'print_2_mail_billing_data' => [entry] }) do
          DataRunner::GroupRefresh.stub(:start!, runner) do
            DataRefresh.run!({ 'print_2_mail_billing_data' => '1' },
                             requested_by: 'employee@example.com',
                             selected_entries: ['51786524'])
          end
        end

        assert_equal ['OMS 51786524'], calls.first.fetch(:entries).map(&:key)
      end
    end

    test 'does not refresh any OMS numbers when selection is empty' do
      entry = Struct.new(:slug, :key) do
        def enabled? = true
      end.new('oms', 'OMS 51786524')
      calls = []

      DslCatalog.stub(:grouped, { 'print_2_mail_billing_data' => [entry] }) do
        DataRunner::GroupRefresh.stub(:start!, ->(**arguments) { calls << arguments }) do
          DataRefresh.run!({ 'print_2_mail_billing_data' => '1' },
                           requested_by: 'employee@example.com', selected_entries: [])
        end
      end

      assert_empty calls
    end

    test 'rebuilds restart entries from OMS numbers still in the queue' do
      Dir.mktmpdir do |directory|
        queue = Pathname.new(directory).join('sent').tap(&:mkpath)
        queue.join('Mail.dat_51786524.zip').write('marker')
        entry = Struct.new(:slug, :key, :config) do
          def enabled? = true
        end.new(
          'oms', 'Oms',
          { orchestration: { root_path: directory, sent_path: 'sent', queue: { path: :sent_path } } }
        )

        DslCatalog.stub(:grouped, { 'print_2_mail_billing_data' => [entry] }) do
          entries = DataRefresh.restart_entries(nil)

          assert_equal ['OMS 51786524'], entries.map(&:key)
          assert_equal %w[oms], entries.map(&:slug)
        end
      end
    end
  end
end # rubocop:enable Metrics/ClassLength
