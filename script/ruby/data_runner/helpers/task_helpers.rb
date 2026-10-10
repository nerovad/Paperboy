# frozen_string_literal: true

require 'English'
require 'fileutils'
require_relative '../log/data_runner_logger'
require_relative '../constants/workflow_paths'
require_relative '../../../../lib/paperboy/file_store'
require_relative 'workspace'

# Shared support for DataRunner Rake task arguments, stage execution, and cleanup.
# rubocop:disable-next Metrics/ModuleLength
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
    'replicate.rb' => 'script/ruby/data_runner/commands/replicate.rb',
    'to_csv.rb' => 'script/ruby/data_runner/commands/to_csv.rb',
    'to_sql.rb' => 'script/ruby/data_runner/commands/to_sql.rb',
    'use_dsl.rb' => 'script/ruby/data_runner/commands/use_dsl.rb',
    'use_sql.rb' => 'script/ruby/data_runner/commands/use_sql.rb'
  }.freeze

  def run_ruby_stage(script, *args, log_selectors: nil, environment: {})
    compact_args = args.compact
    script_path = COMMAND_SCRIPTS.fetch(script, script)
    started_at = Time.now
    process_start = Process.times
    result = execute_stage(script_path, compact_args, environment)

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

  def task_arg(args, argv = ARGV, allow_all: false, required: true)
    value = args[:name] || argv[1]
    value = value.to_s.strip unless value.nil?
    if value.nil? || value.empty?
      abort 'Usage: rake DataRunner:task[dslName|groupName|ALL]' if required

      return nil
    end
    return nil if allow_all && value.casecmp(ALL_SELECTOR).zero?

    value
  end

  def dsl_stub_selector(value)
    value.to_s.split('.').last
  end

  def run_refresh(selector)
    refresh_scripts(selector).each do |stage, script|
      run_ruby_stage(script, selector, log_selectors: log_selectors(stage, selector))
    end
  end

  def run_replicate_stage(selector)
    run_stage_when_wanted(selector, :replicate, 'replicate.rb')
  end

  def refresh_scripts(selector)
    require_relative '../constants/workflow'

    entries = refresh_entries(selector)
    Workflow::REFRESH_SEQUENCE.select do |step, _script|
      entries.any? { |_name, cfg| Workflow.wants_step?(cfg, step) }
    end
  end

  def run_stage_when_wanted(selector, stage, script)
    require_relative '../constants/workflow'
    return unless refresh_entries(selector).any? { |_name, cfg| Workflow.wants_step?(cfg, stage) }

    run_ruby_stage(script, selector, log_selectors: log_selectors(stage, selector))
  end

  def refresh_entries(selector)
    load_dsl_helpers
    selector.nil? ? DSL_MAP : EtlHelpers.selected_dsl_entries(DSL_MAP, [selector])
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

  def execute_stage(script_path, args, environment)
    workspace = DataRunnerWorkspace.new
    success = workspace.run(environment) do |child_environment|
      system(child_environment, 'ruby', Rails.root.join(script_path).to_s, *args)
    end
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
      selected_stage_paths(cfg).each do |stage_dir, filename|
        store, relative_prefix = workflow_stage_store(stage_dir)
        target = [relative_prefix, filename].compact.join('/')
        if store.exist?(target)
          store.remove(target)
          puts "[OK] #{name}: removed #{stage_dir}/#{filename}"
        else
          puts "[SKIP] #{name}: missing #{stage_dir}/#{filename}"
        end
      end
    end
  end
  private_class_method :reset_selected_files

  def selected_stage_paths(cfg)
    output = EtlHelpers.output_for(cfg)
    base = EtlHelpers.base_for(cfg)
    [
      [WorkflowPaths::NORMALIZED_DIR, output],
      [WorkflowPaths::SQL_MAP_DIR, "#{base}.sql"],
      [WorkflowPaths::SQL_SCHEMA_DIR, "#{base}.sql"],
      [WorkflowPaths::APPLIED_DIR, output]
    ]
  end
  private_class_method :selected_stage_paths

  def reset_all_files
    require_relative '../constants/workflow_paths'

    staged_dir_names.each do |dirname|
      display_path = File.join('output/data_runner', dirname)
      store, relative_prefix = workflow_stage_store(WorkflowPaths::OUTPUT_ROOT.join(dirname))

      unless store.directory?(relative_prefix)
        puts "[SKIP] Missing #{display_path}"
        next
      end

      store.clear(relative_prefix)
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

  def workflow_stage_store(stage_dir)
    root = Pathname(WorkflowPaths::OUTPUT_ROOT)
    stage = Pathname(stage_dir)
    return [Paperboy::FileStore.for(root), stage.relative_path_from(root).to_s] if root.extname.casecmp?('.lnk')

    [Paperboy::FileStore.for(stage), nil]
  end
  private_class_method :workflow_stage_store
end

require_relative 'orchestration_helpers'
