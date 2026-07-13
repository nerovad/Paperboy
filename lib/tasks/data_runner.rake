# frozen_string_literal: true

require 'English'
require 'fileutils'
require Rails.root.join('script/log/data_runner_logger').to_s

ETL_ROOT = Rails.root.to_s
ALL_SELECTOR = 'ALL'
COMMAND_SCRIPTS = {
  'create_tables.rb' => 'script/comands/create_tables.rb',
  'download.rb' => 'script/commands/download.rb',
  'drop_tables.rb' => 'script/commands/drop_tables.rb',
  'dsl_stub.rb' => 'script/commands/dsl_stub.rb',
  'dump_sql.rb' => 'script/commands/dump_sql.rb',
  'from_sql.rb' => 'script/commands/from_sql.rb',
  'initial_dsl.rb' => 'script/commands/initial_dsl.rb',
  'inject.rb' => 'script/commands/inject.rb',
  'to_csv.rb' => 'script/commands/to_csv.rb',
  'to_sql.rb' => 'script/commands/to_sql.rb',
  'use_dsl.rb' => 'script/commands/use_dsl.rb',
  'use_sql.rb' => 'script/commands/use_sql.rb'
}.freeze

def run_ruby_stage(script, *args, log_selectors: nil)
  compact_args = args.compact
  script_path = COMMAND_SCRIPTS.fetch(script, script)
  command = ['ruby', script_path, *compact_args].join(' ')
  started_at = Time.now
  process_start = Process.times
  error = nil
  success = false
  exit_status = nil

  begin
    success = system('ruby', File.join(ETL_ROOT, script_path), *compact_args)
    exit_status = $CHILD_STATUS&.exitstatus
  rescue StandardError => e
    error = e
    raise
  ensure
    completed_at = Time.now
    DataRunnerLogger.log_command(
      command: command,
      script: script_path,
      args: compact_args,
      started_at: started_at,
      completed_at: completed_at,
      success: success,
      exit_status: exit_status,
      options: {
        selectors: log_selectors,
        error: error
      }
    )
  end

  process_finish = Process.times

  user_seconds = (process_finish.utime + process_finish.cutime) - (process_start.utime + process_start.cutime)
  puts format('Time: %.3f sec', user_seconds)
  puts

  abort unless success
end

def define_positional_arg_task
  task_name = ARGV[1]
  return if task_name.nil? || task_name.start_with?('-') || Rake::Task.task_defined?(task_name)

  task task_name.to_sym
end

define_positional_arg_task

def task_arg(args, allow_all: false)
  value = args[:name] || ARGV[1]
  value = value.to_s.strip unless value.nil?
  abort 'Usage: rake DataRunner:task[dslName|groupName|ALL]' if value.nil? || value.empty?
  return nil if allow_all && value.casecmp(ALL_SELECTOR).zero?

  value
end

def dsl_stub_selector(value)
  value.to_s.split('.').last
end

def oneshot_log_selectors(step, selector)
  require Rails.root.join('script/commands/dsl_map').to_s
  require Rails.root.join('script/helpers/etl_helpers').to_s
  require Rails.root.join('script/constants/workflow').to_s

  EtlHelpers.selected_dsl_entries(DSL_MAP, [selector]).filter_map do |name, cfg|
    name if Workflow.wants_step?(cfg, step)
  end
end

# rubocop:disable Metrics/BlockLength
namespace :DataRunner do
  desc 'Create a DSL stub file: rake DataRunner:dsl_stub name_of_stub | host.database.schema.dsl_name'
  task :dsl_stub, [:name] do |_task, args|
    run_ruby_stage('dsl_stub.rb', task_arg(args))
  end

  desc 'Create initial DSL files from 00_Inbox source files'
  task :new_dsl, [:name] do |_task, args|
    run_ruby_stage('initial_dsl.rb', task_arg(args))
  end

  desc 'Download or validate configured ETL source files'
  task :download, [:name] do |_task, args|
    run_ruby_stage('download.rb', task_arg(args, allow_all: true))
  end

  desc 'Convert configured source files into normalized CSV files'
  task :to_csv, [:name] do |_task, args|
    run_ruby_stage('to_csv.rb', task_arg(args, allow_all: true))
  end

  desc 'Convert normalized CSV files into DSL map scaffolds'
  task :to_dsl, [:name] do |_task, args|
    run_ruby_stage('csv_to_dsl_map.rb', task_arg(args, allow_all: true))
  end

  desc 'Write SQL Server table scaffold files from DSL mappings'
  task :to_sql, [:name] do |_task, args|
    run_ruby_stage('to_sql.rb', task_arg(args, allow_all: true))
  end

  desc 'Dump live SQL Server table definitions into 04_SQL_SCHEMA'
  task :dump_sql, [:name] do |_task, args|
    run_ruby_stage('dump_sql.rb', task_arg(args, allow_all: true))
  end

  desc 'Export SQL Server tables into 01_Download CSV files'
  task :from_sql, [:name] do |_task, args|
    run_ruby_stage('from_sql.rb', task_arg(args, allow_all: true))
  end

  desc 'Drop configured SQL Server tables'
  task :table_drop, [:name] do |_task, args|
    run_ruby_stage('drop_tables.rb', task_arg(args, allow_all: true))
  end

  desc 'Create configured SQL Server tables'
  task :table_create, [:name] do |_task, args|
    run_ruby_stage('create_tables.rb', task_arg(args, allow_all: true))
  end

  desc 'Apply locked DSL mappings to normalized CSV files'
  task :use_dsl, [:name] do |_task, args|
    run_ruby_stage('use_dsl.rb', task_arg(args, allow_all: true))
  end

  desc 'Update DSL header mappings from reviewed SQL in 04_SQL_SCHEMA'
  task :use_sql, [:name] do |_task, args|
    run_ruby_stage('use_sql.rb', task_arg(args, allow_all: true))
  end

  desc 'Load DSL-applied CSV files into SQL Server'
  task :inject, [:name] do |_task, args|
    run_ruby_stage('inject.rb', task_arg(args, allow_all: true))
  end

  desc 'Run download, to_csv, to_sql, and use_dsl in sequence'
  task :setup, [:name] do |_task, args|
    selector = task_arg(args, allow_all: true)

    run_ruby_stage('download.rb', selector, log_selectors: oneshot_log_selectors(:download, selector))
    run_ruby_stage('to_csv.rb', selector, log_selectors: oneshot_log_selectors(:to_csv, selector))
    run_ruby_stage('to_sql.rb', selector, log_selectors: oneshot_log_selectors(:to_sql, selector))
    run_ruby_stage('use_dsl.rb', selector, log_selectors: oneshot_log_selectors(:use_dsl, selector))
  end

  desc 'Run download, to_csv, to_sql, use_dsl, table_create, and inject in sequence'
  task :oneshot, [:name] do |_task, args|
    selector = task_arg(args, allow_all: true)

    run_ruby_stage('download.rb', selector, log_selectors: oneshot_log_selectors(:download, selector))
    run_ruby_stage('to_csv.rb', selector, log_selectors: oneshot_log_selectors(:to_csv, selector))
    run_ruby_stage('to_sql.rb', selector, log_selectors: oneshot_log_selectors(:to_sql, selector))
    run_ruby_stage('use_dsl.rb', selector, log_selectors: oneshot_log_selectors(:use_dsl, selector))
    run_ruby_stage('create_tables.rb', selector, log_selectors: oneshot_log_selectors(:create_table, selector))
    run_ruby_stage('inject.rb', selector, log_selectors: oneshot_log_selectors(:inject, selector))
  end

  desc 'Run download, to_csv, use_dsl, and inject in sequence'
  task :refresh, [:name] do |_task, args|
    selector = task_arg(args, allow_all: true)

    run_ruby_stage('download.rb', selector, log_selectors: oneshot_log_selectors(:download, selector))
    run_ruby_stage('to_csv.rb', selector, log_selectors: oneshot_log_selectors(:to_csv, selector))
    run_ruby_stage('use_dsl.rb', selector, log_selectors: oneshot_log_selectors(:use_dsl, selector))
    run_ruby_stage('inject.rb', selector, log_selectors: oneshot_log_selectors(:inject, selector))
  end

  desc 'Create a DSL stub, then run dump_sql and use_sql for the DSL name'
  task :sync_dsl, [:name] do |_task, args|
    stub_arg = task_arg(args)
    selector = dsl_stub_selector(stub_arg)

    run_ruby_stage('dsl_stub.rb', stub_arg)
    run_ruby_stage('dump_sql.rb', selector)
    run_ruby_stage('use_sql.rb', selector)
    run_ruby_stage('from_sql.rb', selector)
  end

  desc 'Clear staged generated ETL files'
  task :reset, [:name] do |_task, args|
    puts 'Reset ETL staged files.'

    selector = task_arg(args, allow_all: true)
    if selector
      require Rails.root.join('script/commands/dsl_map').to_s
      require Rails.root.join('script/helpers/etl_helpers').to_s
      require Rails.root.join('script/constants/workflow_paths').to_s

      EtlHelpers.selected_dsl_entries(DSL_MAP, [selector]).each do |name, cfg|
        output = EtlHelpers.output_for(cfg)
        base = EtlHelpers.base_for(cfg)

        [
          File.join(WorkflowPaths::NORMALIZED_DIR, output),
          File.join(WorkflowPaths::SQL_MAP_DIR, "#{base}.sql"),
          File.join(WorkflowPaths::SQL_SCHEMA_DIR, "#{base}.sql"),
          File.join(WorkflowPaths::APPLIED_DIR, output)
        ].each do |path|
          if File.exist?(path)
            FileUtils.rm_f(path)
            puts "[OK] #{name}: removed #{path}"
          else
            puts "[SKIP] #{name}: missing #{path}"
          end
        end
      end

      next
    end

    require Rails.root.join('script/constants/workflow_paths').to_s

    [
      WorkflowPaths::NORMALIZED_DIR_NAME,
      WorkflowPaths::SQL_MAP_DIR_NAME,
      WorkflowPaths::SQL_SCHEMA_DIR_NAME,
      WorkflowPaths::APPLIED_DIR_NAME
    ].each do |dirname|
      path = File.join(ETL_ROOT, dirname)
      display_path = File.join('ruby/etl', dirname)

      unless Dir.exist?(path)
        puts "[SKIP] Missing #{display_path}"
        next
      end

      Dir.children(path).each do |entry|
        FileUtils.rm_rf(File.join(path, entry))
      end

      puts "[OK] Cleared #{display_path}"
    end
  end
end
# rubocop:enable Metrics/BlockLength
