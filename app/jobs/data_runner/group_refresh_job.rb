# frozen_string_literal: true

module DataRunner
  class GroupRefreshJob < ApplicationJob
    queue_as :default

    DOWNLOAD_CONCURRENCY = 4

    def self.download_concurrency = DOWNLOAD_CONCURRENCY

    def perform(group_run_id)
      run = GroupRun.find_by(id: group_run_id)
      return if run.nil? || run.status != 'queued'

      run.update!(status: 'running', started_at: Time.current)
      prepare_log(run)
      process_items(run)
      finish(run)
    rescue ActiveRecord::RecordNotFound
      nil
    rescue StandardError => e
      fail_run(run, e)
      raise
    end

    private

    def process_items(run)
      items = run.items.order(:position).to_a
      DependentTruncate.perform(items.map(&:dsl_name)).each do |message|
        append_log(run.run_id) { |log| log.puts(message) }
      end
      return unless run_active?(run.id)

      queue = Queue.new
      dsl_names = items.map(&:dsl_name).join(',')
      items.each { |item| queue << prepare_item(run, item, dsl_names) }
      return unless run_active?(run.id)

      stop = RefreshStop.new
      monitor = stop.watch(run.id)
      GroupRefreshWorkers.new(run, queue, stop, method(:append_log)).run
    ensure
      note_stopped(run) if stop && !run_active?(run.id)
      stop&.stop!
      monitor&.join(2)
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

    def item_workspace(run, item)
      return unless run.group_name == P2m::DataRefresh::GROUP_RUN_NAME

      Rails.root.join('tmp/data_runner_runs', run.run_id, item.id.to_s)
    end

    def finish(run)
      run.reload
      return unless run.active?

      run.update!(status: run.failed_count.positive? ? 'failed' : 'succeeded',
                  current_dsl: nil, completed_at: Time.current)
    rescue ActiveRecord::RecordNotFound
      nil
    end

    def fail_run(run, error)
      return if run.nil?

      run.reload
      return if run.finished?

      run.update(status: 'failed', current_dsl: nil, completed_at: Time.current)
      append_log(run.run_id) { |log| log.puts("[FAIL] Group refresh: #{error.message}") }
    rescue ActiveRecord::RecordNotFound
      nil
    end

    def run_active?(run_id)
      GroupRun.exists?(id: run_id, status: GroupRun::ACTIVE_STATUSES)
    end

    def note_stopped(run)
      return if @stop_logged

      @stop_logged = true
      append_log(run.run_id) { |log| log.puts('[STOP] Group refresh stopped. Progress was cleared.') }
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
