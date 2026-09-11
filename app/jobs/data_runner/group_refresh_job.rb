# frozen_string_literal: true

require 'fileutils'

module DataRunner
  class GroupRefreshJob < ApplicationJob
    queue_as :default

    DOWNLOAD_CONCURRENCY = 4

    class SynchronizedOutput
      def initialize(output, mutex)
        @output = output
        @mutex = mutex
      end

      def puts(*args)
        @mutex.synchronize { @output.puts(*args) }
      end

      def write(content)
        @mutex.synchronize { @output.write(content) }
      end

      def flush
        @mutex.synchronize { @output.flush }
      end
    end

    def perform(group_run_id)
      run = GroupRun.find(group_run_id)
      return unless run.status == 'queued'

      run.update!(status: 'running', started_at: Time.current)
      prepare_log(run)
      process_items(run)
      finish(run)
    rescue StandardError => e
      fail_run(run, e)
      raise
    end

    private

    def process_items(run)
      items = run.items.order(:position).to_a
      dsl_names = items.map(&:dsl_name).join(',')
      work = items.map { |item| prepare_item(run, item, dsl_names) }
      queue = Queue.new
      work.each { |item| queue << item }
      ActiveRecord::Base.connection_pool.release_connection
      File.open(TaskRunner.output_path(run.run_id), 'a') do |output|
        log = SynchronizedOutput.new(output, Mutex.new)
        workers = [worker_count(run), work.size].min.times.map do
          Thread.new { work_items(run.id, queue, log) }
        end
        workers.each(&:value)
      end
    end

    def worker_count(_run) = DOWNLOAD_CONCURRENCY

    def work_items(run_id, queue, log)
      while (item = queue.pop(true))
        process_item(run_id, item, log)
      end
    rescue ThreadError
      nil
    end

    def prepare_item(run, item, dsl_names)
      started_at = Time.current
      workspace = item_workspace(run, item)
      item.update!(status: 'running', started_at: started_at)
      environment = {
        'DATARUNNER_RUN_ID' => run.run_id,
        'DATARUNNER_RUN_DSLS' => dsl_names
      }
      environment['DATARUNNER_OUTPUT_ROOT'] = workspace.to_s if workspace
      oms_number = item.dsl_name.match(/\AOMS (\d{8,9})\z/)&.[](1)
      raise ArgumentError, "OMS number missing from refresh item #{item.id}" if
        run.group_name == P2m::DataRefresh::GROUP_RUN_NAME && oms_number.nil?

      environment['DATARUNNER_QUEUE_OMS'] = oms_number if oms_number
      { id: item.id, name: item.dsl_name, slug: item.dsl_slug, workspace: workspace,
        environment: environment, started_clock: Process.clock_gettime(Process::CLOCK_MONOTONIC) }
    end

    def process_item(run_id, item, log)
      status = TaskRunner.run_selector!(task: 'refresh', selector: item[:slug], output: log,
                                        environment: item[:environment])
      item_status = status.success? ? 'succeeded' : 'failed'
      complete_item(run_id, item, status: item_status)
    rescue StandardError => e
      complete_item(run_id, item, status: 'failed', error_message: e.message)
      append_log(run_id) { |failure_log| failure_log.puts("[FAIL] #{item[:name]}: #{e.message}") }
    ensure
      workspace = item[:workspace]
      FileUtils.rm_rf(workspace) if workspace&.to_s&.start_with?(Rails.root.join('tmp/data_runner_runs').to_s)
      ActiveRecord::Base.connection_pool.release_connection
    end

    def complete_item(run_id, item, status:, error_message: nil)
      duration_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - item[:started_clock]) * 1000).round
      GroupRunItem.find(item[:id]).update!(status: status, error_message: error_message,
                                           duration_ms: duration_ms, completed_at: Time.current)
      GroupRun.increment_counter(:completed_count, run_id)
      GroupRun.increment_counter(:failed_count, run_id) if status == 'failed'
    end

    def item_workspace(run, item)
      return unless run.group_name == P2m::DataRefresh::GROUP_RUN_NAME

      Rails.root.join('tmp/data_runner_runs', run.run_id, item.id.to_s)
    end

    def finish(run)
      run.reload
      run.update!(status: run.failed_count.positive? ? 'failed' : 'succeeded',
                  current_dsl: nil, completed_at: Time.current)
    end

    def fail_run(run, error)
      return if run.nil? || run.finished?

      run.update(status: 'failed', current_dsl: nil, completed_at: Time.current)
      append_log(run.run_id) { |log| log.puts("[FAIL] Group refresh: #{error.message}") }
    end

    def prepare_log(run)
      path = TaskRunner.output_path(run.run_id)
      path.dirname.mkpath
      path.write("Refreshing #{run.group_name.humanize} (#{run.total_count} DSLs)\n\n")
    end

    def append_log(run_id, &block)
      @log_mutex ||= Mutex.new
      @log_mutex.synchronize { File.open(TaskRunner.output_path(run_id), 'a', &block) }
    end
  end
end
