# frozen_string_literal: true

module DataRunner
  # Stops rake children started by this worker. The web process deletes the
  # group run; only the worker process knows those pids.
  class RefreshStop
    POLL_SECONDS = 0.25

    def initialize
      @mutex = Mutex.new
      @pids = []
      @stopped = false
    end

    def stopped?
      @mutex.synchronize { @stopped }
    end

    def track(pid)
      pid = pid.to_i
      return if pid <= 0

      already_stopped = false
      @mutex.synchronize do
        if @stopped
          already_stopped = true
        else
          @pids << pid
        end
      end
      terminate(pid) if already_stopped
    end

    def forget(pid)
      @mutex.synchronize { @pids.delete(pid.to_i) }
    end

    def stop!
      pids = @mutex.synchronize do
        @stopped = true
        @pids.dup
      end
      pids.each { |pid| terminate(pid) }
    end

    def watch(run_id)
      Thread.new do
        until stopped?
          unless run_active?(run_id)
            stop!
            break
          end
          sleep POLL_SECONDS
        end
      ensure
        ActiveRecord::Base.connection_pool.release_connection
      end
    end

    def terminate(pid)
      pid = pid.to_i
      return if pid <= 0

      signal(pid, 'TERM')
      return unless alive?(pid)

      deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + 0.5
      sleep 0.05 while alive?(pid) && Process.clock_gettime(Process::CLOCK_MONOTONIC) < deadline
      signal(pid, 'KILL') if alive?(pid)
    end

    private

    def run_active?(run_id)
      ActiveRecord::Base.connection_pool.with_connection do
        GroupRun.exists?(id: run_id, status: GroupRun::ACTIVE_STATUSES)
      end
    end

    def signal(pid, name)
      Process.kill(name, -pid)
    rescue Errno::ESRCH, Errno::EPERM
      begin
        Process.kill(name, pid)
      rescue Errno::ESRCH, Errno::EPERM
        nil
      end
    end

    def alive?(pid)
      Process.kill(0, pid)
      true
    rescue Errno::ESRCH
      false
    rescue Errno::EPERM
      true
    end
  end
end
