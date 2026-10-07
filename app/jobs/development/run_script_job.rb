# frozen_string_literal: true

require 'open3'

module Development
  class RunScriptJob < ApplicationJob
    # The shared Solid Queue database is claimed by other workstations.
    # Tests keep the queue adapter; everywhere else the submitting process runs
    # the command so the script and its checkout stay on this machine.
    def self.perform_later(run_id, ...)
      return super if Rails.env.test?

      RunLauncher.enqueue(run_id)
    end

    def perform(run_id)
      run = Development::Run.find(run_id)
      run.update!(status: 'running', started_at: Time.current)
      script = ScriptCatalog.find(run.script_key)
      program = script && CommandBuilder.new(script, []).program
      executable, *arguments = run.command
      raise ArgumentError, 'Run command does not match its catalog script' unless program && executable == program

      output, status = Open3.capture2e([program, program], *arguments, chdir: Rails.root.to_s)
      run.update!(status: status.success? ? 'succeeded' : 'failed', output: output, exit_status: status.exitstatus,
                  finished_at: Time.current)
    rescue StandardError => e
      run&.update(status: 'failed', output: "#{e.class}: #{e.message}", exit_status: 1, finished_at: Time.current)
      raise
    end
  end
end
