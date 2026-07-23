# frozen_string_literal: true

require 'English'
require 'fileutils'
require_relative '../log/data_runner_logger'

# Shared support for DataRunner Rake task arguments, stage execution, and cleanup.
module DataRunnerTaskHelpers
  module_function

  ALL_SELECTOR = 'ALL'
  COMMAND_SCRIPTS = {
    'create_tables.rb' => 'script/ruby/data_runner/commands/create_tables.rb',
    'download.rb' => 'script/ruby/data_runner/commands/download.rb',
    'drop_tables.rb' => 'script/ruby/data_runner/commands/drop_tables.rb',
    'dsl_stub.rb' => 'script/ruby/data_runner/commands/dsl_stub.rb',
    'dump_sql.rb' => 'script/ruby/data_runner/commands/dump_sql.rb',
    'from_sql.rb' => 'script/ruby/data_runner/commands/from_sql.rb',
    'initial_dsl.rb' => 'script/ruby/data_runner/commands/initial_dsl.rb',
    'inject.rb' => 'script/ruby/data_runner/commands/inject.rb',
    'to_csv.rb' => 'script/ruby/data_runner/commands/to_csv.rb',
    'to_sql.rb' => 'script/ruby/data_runner/commands/to_sql.rb',
    'use_dsl.rb' => 'script/ruby/data_runner/commands/use_dsl.rb',
    'use_sql.rb' => 'script/ruby/data_runner/commands/use_sql.rb'
  }.freeze

  def run_ruby_stage(script, *args, log_selectors: nil)
    compact_args = args.compact
    script_path = COMMAND_SCRIPTS.fetch(script, script)
    started_at = Time.now
    process_start = Process.times
    result = execute_stage(script_path, compact_args)

    log_stage(script_path, compact_args, started_at, result, log_selectors)
    print_elapsed_time(process_start)
    abort unless result[:success]
  rescue StandardError => e
    log_stage(script_path, compact_args, started_at, { success: false, error: e }, log_selectors)
    raise
  end

  def define_positional_arg_task(argv = ARGV)
    task_name = argv[1]
    return if task_name.nil? || task_name.start_with?('-') || Rake::Task.task_defined?(task_name)

    Rake::Task.define_task(task_name.to_sym)
  end

  def task_arg(args, argv = ARGV, allow_all: false)
    value = args[:name] || argv[1]
    value = value.to_s.strip unless value.nil?
    abort 'Usage: rake DataRunner:task[dslName|groupName|ALL]' if value.nil? || value.empty?
    return nil if allow_all && value.casecmp(ALL_SELECTOR).zero?

    value
  end

  def dsl_stub_selector(value)
    value.to_s.split('.').last
  end

  def log_selectors(step, selector)
    load_dsl_helpers
    require_relative '../constants/workflow'

    EtlHelpers.selected_dsl_entries(DSL_MAP, [selector]).filter_map do |name, cfg|
      name if Workflow.wants_step?(cfg, step)
    end
  end

  def reset_staged_files(selector)
    selector ? reset_selected_files(selector) : reset_all_files
  end

  def execute_stage(script_path, args)
    success = system('ruby', Rails.root.join(script_path).to_s, *args)
    { success: success, exit_status: $CHILD_STATUS&.exitstatus }
  end
  private_class_method :execute_stage

  def log_stage(script_path, args, started_at, result, selectors)
    DataRunnerLogger.log_command(
      command: ['ruby', script_path, *args].join(' '),
      script: script_path,
      args: args,
      started_at: started_at,
      completed_at: Time.now,
      success: result[:success],
      exit_status: result[:exit_status],
      options: { selectors: selectors, error: result[:error] }
    )
  end
  private_class_method :log_stage

  def print_elapsed_time(process_start)
    process_finish = Process.times
    user_seconds = (process_finish.utime + process_finish.cutime) - (process_start.utime + process_start.cutime)
    puts format('Time: %.3f sec', user_seconds)
    puts
  end
  private_class_method :print_elapsed_time

  def load_dsl_helpers
    require_relative '../commands/dsl_map'
    require_relative 'etl_helpers'
  end
  private_class_method :load_dsl_helpers

  def reset_selected_files(selector)
    load_dsl_helpers
    require_relative '../constants/workflow_paths'

    EtlHelpers.selected_dsl_entries(DSL_MAP, [selector]).each do |name, cfg|
      selected_stage_paths(cfg).each do |path|
        if File.exist?(path)
          FileUtils.rm_f(path)
          puts "[OK] #{name}: removed #{path}"
        else
          puts "[SKIP] #{name}: missing #{path}"
        end
      end
    end
  end
  private_class_method :reset_selected_files

  def selected_stage_paths(cfg)
    output = EtlHelpers.output_for(cfg)
    base = EtlHelpers.base_for(cfg)
    [
      File.join(WorkflowPaths::NORMALIZED_DIR, output),
      File.join(WorkflowPaths::SQL_MAP_DIR, "#{base}.sql"),
      File.join(WorkflowPaths::SQL_SCHEMA_DIR, "#{base}.sql"),
      File.join(WorkflowPaths::APPLIED_DIR, output)
    ]
  end
  private_class_method :selected_stage_paths

  def reset_all_files
    require_relative '../constants/workflow_paths'

    staged_dir_names.each do |dirname|
      path = Rails.root.join(dirname)
      display_path = File.join('ruby/etl', dirname)

      unless Dir.exist?(path)
        puts "[SKIP] Missing #{display_path}"
        next
      end

      Dir.children(path).each { |entry| FileUtils.rm_rf(path.join(entry)) }
      puts "[OK] Cleared #{display_path}"
    end
  end
  private_class_method :reset_all_files

  def staged_dir_names
    [
      WorkflowPaths::NORMALIZED_DIR_NAME,
      WorkflowPaths::SQL_MAP_DIR_NAME,
      WorkflowPaths::SQL_SCHEMA_DIR_NAME,
      WorkflowPaths::APPLIED_DIR_NAME
    ]
  end
  private_class_method :staged_dir_names
end
