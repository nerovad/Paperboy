# frozen_string_literal: true

module Development
  # Development scripts have to run in the process that queued them.
  # Paperboy_Dev's Solid Queue is shared by every workstation, and a worker
  # whose checkout does not contain RunScriptJob claims the row and fails it
  # before this app's worker can start the command.
  class RunLauncher
    ADAPTER = ActiveJob::QueueAdapters::AsyncAdapter.new

    def self.enqueue(run_id)
      job = RunScriptJob.new(run_id)
      ADAPTER.enqueue(job)
      job
    end
  end
end
