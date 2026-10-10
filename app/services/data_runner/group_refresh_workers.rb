# frozen_string_literal: true

require 'fileutils'

module DataRunner
  # Runs the queued DSL refreshes for one group run and stops when that run is cleared.
  class GroupRefreshWorkers
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

    def initialize(run, queue, stop, log)
      @group_run_id = run.id
      @log_id = run.run_id
      @queue = queue
      @stop = stop
      @log = log
    end

    def run
      ActiveRecord::Base.connection_pool.release_connection
      File.open(TaskRunner.output_path(@log_id), 'a') do |output|
        log = SynchronizedOutput.new(output, Mutex.new)
        workers = [GroupRefreshJob.download_concurrency, @queue.size].min.times.map do
          Thread.new { work_items(log) }
        end
        workers.each(&:value)
      end
    end

    private

    def work_items(log)
      while (item = @queue.pop(true))
        break if @stop.stopped? || !run_active?

        process_item(item, log)
      end
    rescue ThreadError
      nil
    ensure
      ActiveRecord::Base.connection_pool.release_connection
    end

    def process_item(item, log)
      return if @stop.stopped? || !run_active?
      return unless claim_item?(item)

      ActiveRecord::Base.connection_pool.release_connection
      pid = nil
      status = TaskRunner.run_selector!(
        task: 'refresh', selector: item[:slug], output: log, environment: item[:environment],
        on_start: lambda { |child_pid|
          pid = child_pid
          @stop.track(child_pid)
        }
      )
      return if @stop.stopped? || !run_active?

      complete_item(item, status.success? ? 'succeeded' : 'failed')
    rescue StandardError => e
      return if @stop.stopped? || e.is_a?(ActiveRecord::RecordNotFound)

      complete_item(item, 'failed', e.message)
      @log.call(@log_id) { |failure_log| failure_log.puts("[FAIL] #{item[:name]}: #{e.message}") }
    ensure
      @stop.forget(pid) if pid
      remove_workspace(item[:workspace])
      ActiveRecord::Base.connection_pool.release_connection
    end

    def claim_item?(item)
      now = Time.current
      claimed = GroupRunItem.where(id: item[:id], status: 'pending').update_all(
        status: 'running', started_at: now, updated_at: now
      )
      return false unless claimed == 1

      item[:started_clock] = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      true
    end

    def complete_item(item, status, error_message = nil)
      duration_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - item[:started_clock]) * 1000).round
      GroupRunItem.find(item[:id]).update!(status: status, error_message: error_message,
                                           duration_ms: duration_ms, completed_at: Time.current)
      GroupRun.increment_counter(:completed_count, @group_run_id)
      GroupRun.increment_counter(:failed_count, @group_run_id) if status == 'failed'
    rescue ActiveRecord::RecordNotFound
      nil
    end

    def run_active?
      GroupRun.exists?(id: @group_run_id, status: GroupRun::ACTIVE_STATUSES)
    end

    def remove_workspace(workspace)
      return unless workspace&.to_s&.start_with?(Rails.root.join('tmp/data_runner_runs').to_s)

      FileUtils.rm_rf(workspace)
    end
  end
end
