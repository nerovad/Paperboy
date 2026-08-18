# frozen_string_literal: true

require 'open3'
require 'securerandom'

class TaskRunner
  TASK_COMMANDS = {
    'download' => 'DataRunner:download',
    'to_csv' => 'DataRunner:to_csv',
    'to_sql' => 'DataRunner:to_sql',
    'dump_sql' => 'DataRunner:dump_sql',
    'from_sql' => 'DataRunner:from_sql',
    'table_drop' => 'DataRunner:table_drop',
    'table_create' => 'DataRunner:table_create',
    'use_dsl' => 'DataRunner:use_dsl',
    'use_sql' => 'DataRunner:use_sql',
    'inject' => 'DataRunner:inject',
    'oneshot' => 'DataRunner:oneshot',
    'refresh' => 'DataRunner:refresh',
    'reset' => 'DataRunner:reset'
  }.freeze
  TASKS = TASK_COMMANDS.keys.freeze
  Result = Data.define(:id, :success)

  def self.run!(task:, selector:)
    TASK_COMMANDS.fetch(task) { raise ArgumentError, 'Task is not allowed' }
    selector_names = selector_names!(selector)
    id = SecureRandom.uuid
    path = output_path(id)
    path.dirname.mkpath
    successes = []
    File.open(path, 'w') do |output|
      if selector_names.empty?
        output.puts 'No enabled DSLs matched this request.'
      else
        selector_names.each do |selector_name|
          status = run_selector!(task: task, selector: selector_name, output: output)
          successes << status.success?
        end
      end
    end

    Result.new(id: id, success: successes.all?)
  end

  def self.run_selector!(task:, selector:, output:)
    task_name = TASK_COMMANDS.fetch(task) { raise ArgumentError, 'Task is not allowed' }
    selector_name = selector_name!(selector)
    command = [Gem.ruby, Rails.root.join('bin/rake').to_s, task_name, selector_name]
    output.puts "$ #{command.join(' ')}", ''
    output.flush

    status = nil
    Open3.popen2e(*command, chdir: Rails.root.to_s) do |stdin, stream, wait_thread|
      stdin.close
      stream.each do |line|
        output.write(line)
        output.flush
      end
      status = wait_thread.value
    end
    output.puts
    status
  end

  def self.output!(id)
    raise ActiveRecord::RecordNotFound unless id.match?(/\A[0-9a-f-]{36}\z/)

    path = output_path(id)
    raise ActiveRecord::RecordNotFound unless path.file?

    path.read
  end

  def self.output_path(id)
    Rails.root.join('tmp', 'web_runs', "#{id}.log")
  end

  def self.selector_name!(selector)
    entry = DslCatalog.entries.find { |candidate| candidate.slug == selector || candidate.key == selector }
    return entry.key if entry

    return selector if DslCatalog.grouped.key?(selector)

    raise ActiveRecord::RecordNotFound, 'Unknown DSL selector'
  end

  def self.selector_names!(selector)
    Array(selector).map { |value| selector_name!(value) }
  end
end
