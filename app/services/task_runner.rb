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
    task_name = TASK_COMMANDS.fetch(task) { raise ArgumentError, 'Task is not allowed' }

    selector_names = selector_names!(selector)
    id = SecureRandom.uuid
    path = Rails.root.join('tmp', 'web_runs', "#{id}.log")
    path.dirname.mkpath
    runs = selector_names.map do |selector_name|
      command = [Gem.ruby, Rails.root.join('bin/rake').to_s, task_name, selector_name]
      output, status = Open3.capture2e(*command, chdir: Rails.root.to_s)
      ["$ #{command.join(' ')}\n\n#{output}", status.success?]
    end

    if runs.empty?
      path.write("No enabled DSLs matched this request.\n")
      return Result.new(id: id, success: true)
    end

    path.write(runs.map(&:first).join("\n"))
    Result.new(id: id, success: runs.all?(&:second))
  end

  def self.output!(id)
    raise ActiveRecord::RecordNotFound unless id.match?(/\A[0-9a-f-]{36}\z/)

    path = Rails.root.join('tmp', 'web_runs', "#{id}.log")
    raise ActiveRecord::RecordNotFound unless path.file?

    path.read
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
