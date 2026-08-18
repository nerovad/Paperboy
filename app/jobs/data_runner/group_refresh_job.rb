# frozen_string_literal: true

module DataRunner
  class GroupRefreshJob < ApplicationJob
    queue_as :default

    def perform(group_run_id)
      run = GroupRun.find(group_run_id)
      return unless run.status == 'queued'

      run.update!(status: 'running', started_at: Time.current)
      prepare_log(run)
      run.items.order(:position).each { |item| process_item(run, item) }
      finish(run)
    rescue StandardError => e
      fail_run(run, e)
      raise
    end

    private

    def process_item(run, item)
      item.update!(status: 'running', started_at: Time.current)
      run.update!(current_dsl: item.dsl_name)
      status = append_log(run) do |log|
        TaskRunner.run_selector!(task: 'refresh', selector: item.dsl_slug, output: log)
      end
      item_status = status.success? ? 'succeeded' : 'failed'
      item.update!(status: item_status, completed_at: Time.current)
      run.increment!(:completed_count)
      run.increment!(:failed_count) unless status.success?
    rescue StandardError => e
      item.update!(status: 'failed', error_message: e.message, completed_at: Time.current)
      run.increment!(:completed_count)
      run.increment!(:failed_count)
      append_log(run) { |log| log.puts("[FAIL] #{item.dsl_name}: #{e.message}") }
    end

    def finish(run)
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
      File.open(TaskRunner.output_path(run.run_id), 'a', &block)
    end
  end
end
