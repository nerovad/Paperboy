# frozen_string_literal: true

require Rails.root.join('script/ruby/data_runner/helpers/task_helpers').to_s

DataRunnerTaskHelpers.define_positional_arg_task

namespace :DataRunner do
  desc 'Create a DSL stub file: rake DataRunner:dsl_stub name_of_stub | host.database.schema.dsl_name'
  task :dsl_stub, [:name] do |_task, args|
    DataRunnerTaskHelpers.run_ruby_stage('dsl_stub.rb', DataRunnerTaskHelpers.task_arg(args))
  end

  desc 'Create initial DSL files from 00_Inbox source files'
  task :new_dsl, [:name] do |_task, args|
    DataRunnerTaskHelpers.run_ruby_stage('initial_dsl.rb', DataRunnerTaskHelpers.task_arg(args))
  end

  desc 'Download or validate configured ETL source files'
  task :download, [:name] do |_task, args|
    DataRunnerTaskHelpers.run_ruby_stage('download.rb', DataRunnerTaskHelpers.task_arg(args, allow_all: true))
  end

  desc 'Convert configured source files into normalized CSV files'
  task :to_csv, [:name] do |_task, args|
    DataRunnerTaskHelpers.run_ruby_stage('to_csv.rb', DataRunnerTaskHelpers.task_arg(args, allow_all: true))
  end

  desc 'Convert normalized CSV files into DSL map scaffolds'
  task :to_dsl, [:name] do |_task, args|
    DataRunnerTaskHelpers.run_ruby_stage('csv_to_dsl_map.rb', DataRunnerTaskHelpers.task_arg(args, allow_all: true))
  end

  desc 'Write SQL Server table scaffold files from DSL mappings'
  task :to_sql, [:name] do |_task, args|
    DataRunnerTaskHelpers.run_ruby_stage('to_sql.rb', DataRunnerTaskHelpers.task_arg(args, allow_all: true))
  end

  desc 'Dump live SQL Server table definitions into 04_SQL_SCHEMA'
  task :dump_sql, [:name] do |_task, args|
    DataRunnerTaskHelpers.run_ruby_stage('dump_sql.rb', DataRunnerTaskHelpers.task_arg(args, allow_all: true))
  end

  desc 'Export SQL Server tables into 01_Download CSV files'
  task :from_sql, [:name] do |_task, args|
    DataRunnerTaskHelpers.run_ruby_stage('from_sql.rb', DataRunnerTaskHelpers.task_arg(args, allow_all: true))
  end

  desc 'Drop configured SQL Server tables'
  task :table_drop, [:name] do |_task, args|
    DataRunnerTaskHelpers.run_ruby_stage('drop_tables.rb', DataRunnerTaskHelpers.task_arg(args, allow_all: true))
  end

  desc 'Create configured SQL Server tables'
  task :table_create, [:name] do |_task, args|
    DataRunnerTaskHelpers.run_ruby_stage('create_tables.rb', DataRunnerTaskHelpers.task_arg(args, allow_all: true))
  end

  desc 'Apply locked DSL mappings to normalized CSV files'
  task :use_dsl, [:name] do |_task, args|
    DataRunnerTaskHelpers.run_ruby_stage('use_dsl.rb', DataRunnerTaskHelpers.task_arg(args, allow_all: true))
  end

  desc 'Update DSL header mappings from reviewed SQL in 04_SQL_SCHEMA'
  task :use_sql, [:name] do |_task, args|
    DataRunnerTaskHelpers.run_ruby_stage('use_sql.rb', DataRunnerTaskHelpers.task_arg(args, allow_all: true))
  end

  desc 'Load DSL-applied CSV files into SQL Server'
  task :inject, [:name] do |_task, args|
    DataRunnerTaskHelpers.run_ruby_stage('inject.rb', DataRunnerTaskHelpers.task_arg(args, allow_all: true))
  end

  desc 'Run download, to_csv, to_sql, and use_dsl in sequence'
  task :setup, [:name] do |_task, args|
    selector = DataRunnerTaskHelpers.task_arg(args, allow_all: true)

    DataRunnerTaskHelpers.run_ruby_stage('download.rb', selector, log_selectors: DataRunnerTaskHelpers.log_selectors(:download, selector))
    DataRunnerTaskHelpers.run_ruby_stage('to_csv.rb', selector, log_selectors: DataRunnerTaskHelpers.log_selectors(:to_csv, selector))
    DataRunnerTaskHelpers.run_ruby_stage('to_sql.rb', selector, log_selectors: DataRunnerTaskHelpers.log_selectors(:to_sql, selector))
    DataRunnerTaskHelpers.run_ruby_stage('use_dsl.rb', selector, log_selectors: DataRunnerTaskHelpers.log_selectors(:use_dsl, selector))
  end

  desc 'Run download, to_csv, to_sql, use_dsl, table_create, and inject in sequence'
  task :oneshot, [:name] do |_task, args|
    selector = DataRunnerTaskHelpers.task_arg(args, allow_all: true)

    DataRunnerTaskHelpers.run_ruby_stage('download.rb', selector, log_selectors: DataRunnerTaskHelpers.log_selectors(:download, selector))
    DataRunnerTaskHelpers.run_ruby_stage('to_csv.rb', selector, log_selectors: DataRunnerTaskHelpers.log_selectors(:to_csv, selector))
    DataRunnerTaskHelpers.run_ruby_stage('to_sql.rb', selector, log_selectors: DataRunnerTaskHelpers.log_selectors(:to_sql, selector))
    DataRunnerTaskHelpers.run_ruby_stage('use_dsl.rb', selector, log_selectors: DataRunnerTaskHelpers.log_selectors(:use_dsl, selector))
    DataRunnerTaskHelpers.run_ruby_stage('create_tables.rb', selector, log_selectors: DataRunnerTaskHelpers.log_selectors(:create_table, selector))
    DataRunnerTaskHelpers.run_ruby_stage('inject.rb', selector, log_selectors: DataRunnerTaskHelpers.log_selectors(:inject, selector))
  end

  desc 'Run download, to_csv, use_dsl, and inject in sequence'
  task :refresh, [:name] do |_task, args|
    selector = DataRunnerTaskHelpers.task_arg(args, allow_all: true)

    DataRunnerTaskHelpers.run_ruby_stage('download.rb', selector, log_selectors: DataRunnerTaskHelpers.log_selectors(:download, selector))
    DataRunnerTaskHelpers.run_ruby_stage('to_csv.rb', selector, log_selectors: DataRunnerTaskHelpers.log_selectors(:to_csv, selector))
    DataRunnerTaskHelpers.run_ruby_stage('use_dsl.rb', selector, log_selectors: DataRunnerTaskHelpers.log_selectors(:use_dsl, selector))
    DataRunnerTaskHelpers.run_ruby_stage('inject.rb', selector, log_selectors: DataRunnerTaskHelpers.log_selectors(:inject, selector))
  end

  desc 'Create a DSL stub, then run dump_sql and use_sql for the DSL name'
  task :sync_dsl, [:name] do |_task, args|
    stub_arg = DataRunnerTaskHelpers.task_arg(args)
    selector = DataRunnerTaskHelpers.dsl_stub_selector(stub_arg)

    DataRunnerTaskHelpers.run_ruby_stage('dsl_stub.rb', stub_arg)
    DataRunnerTaskHelpers.run_ruby_stage('dump_sql.rb', selector)
    DataRunnerTaskHelpers.run_ruby_stage('use_sql.rb', selector)
    DataRunnerTaskHelpers.run_ruby_stage('from_sql.rb', selector)
  end

  desc 'Clear staged generated ETL files'
  task :reset, [:name] do |_task, args|
    puts 'Reset ETL staged files.'

    selector = DataRunnerTaskHelpers.task_arg(args, allow_all: true)
    DataRunnerTaskHelpers.reset_staged_files(selector)
  end
end
