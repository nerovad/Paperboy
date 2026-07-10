# frozen_string_literal: true

class RakeTaskCatalog
  class << self
    def data_runner
      Rails.application.load_tasks
      Rake::Task.tasks.filter_map do |task|
        task.name.delete_prefix("DataRunner:") if task.name.start_with?("DataRunner:")
      end
    end

    def runnable
      data_runner & TaskRunner::TASKS
    end
  end
end
