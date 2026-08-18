# frozen_string_literal: true

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
      item_ids = Queue.new
      run.items.order(:position).ids.each { |id| item_ids << id }
      workers = [DOWNLOAD_CONCURRENCY, item_ids.size].min.times.map do
        Thread.new { work_items(run.id, item_ids) }
      end
      workers.each(&:value)
    end

    def work_items(run_id, item_ids)
      Rails.application.executor.wrap do
        while (item_id = item_ids.pop(true))
          process_item(GroupRun.find(run_id), GroupRunItem.find(item_id))
        end
      rescue ThreadError
        nil
      end
    end

    def process_item(run, item)
      started_at = Time.current
      started_clock = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      item.update!(status: 'running', started_at: started_at)
      status = with_log(run) do |log|
        TaskRunner.run_selector!(task: 'refresh', selector: item.dsl_slug, output: log)
      end
      item_status = status.success? ? 'succeeded' : 'failed'
      complete_item(run, item, status: item_status, started_clock: started_clock)
    rescue StandardError => e
      complete_item(run, item, status: 'failed', started_clock: started_clock, error_message: e.message)
      append_log(run) { |log| log.puts("[FAIL] #{item.dsl_name}: #{e.message}") }
    end

    def complete_item(run, item, status:, started_clock:, error_message: nil)
      duration_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started_clock) * 1000).round
      item.update!(status: status, error_message: error_message, duration_ms: duration_ms, completed_at: Time.current)
      GroupRun.increment_counter(:completed_count, run.id)
      GroupRun.increment_counter(:failed_count, run.id) if status == 'failed'
    end

    def finish(run)
      run.reload
      run.update!(status: run.failed_count.positive? ? 'failed' : 'succeeded',
                  current_dsl: nil, completed_at: Time.current)
    end

    def fail_run(run, error)
      return if run.nil? || run.finished?

      run.update(status: 'failed', current_dsl: nil, completed_at: Time.current)
      append_log(run) { |log| log.puts("[FAIL] Group refresh: #{error.message}") }
    end

    def prepare_log(run)
      path = TaskRunner.output_path(run.run_id)
      path.dirname.mkpath
      path.write("Refreshing #{run.group_name.humanize} (#{run.total_count} DSLs)\n\n")
    end

    def append_log(run, &block)
      @log_mutex ||= Mutex.new
      @log_mutex.synchronize { File.open(TaskRunner.output_path(run.run_id), 'a', &block) }
    end

    def with_log(run)
      @log_mutex ||= Mutex.new
      File.open(TaskRunner.output_path(run.run_id), 'a') do |output|
        yield SynchronizedOutput.new(output, @log_mutex)
      end
    end
  end
end
