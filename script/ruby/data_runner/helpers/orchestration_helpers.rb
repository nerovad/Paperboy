# frozen_string_literal: true

# Stage-by-stage orchestration support for control-only DataRunner DSL entries.
require 'date'
require 'pathname'

# rubocop:disable Metrics/ModuleLength
module DataRunnerTaskHelpers
  module_function

  ORCHESTRATION_CONCURRENCY = 4

  ORCHESTRATED_SCRIPTS = {
    to_csv: 'to_csv.rb',
    to_sql: 'to_sql.rb',
    drop_table: 'drop_tables.rb',
    create_table: 'create_tables.rb',
    dump_sql: 'dump_sql.rb',
    use_sql: 'use_sql.rb',
    use_dsl: 'use_dsl.rb',
    inject: 'inject.rb'
  }.freeze
  LIFECYCLE_DIRECTORIES = {
    preprocessing: 'preprocess',
    postprocessing: 'postprocess'
  }.freeze

  def orchestrated?(selector)
    !orchestration_entry(selector).nil?
  end

  def run_stage_or_orchestration(selector, stage, script)
    if orchestrated?(selector)
      run_orchestration_stage(selector, stage)
    else
      run_ruby_stage(script, selector, log_selectors: log_selectors(stage, selector))
    end
  end

  def run_orchestration_stage(selector, stage)
    name, cfg = orchestration_entry(selector)
    orchestration = resolved_orchestration(name, cfg.fetch(:orchestration))

    case stage.to_sym
    when :download
      run_tracked_validation(name, orchestration)
    when :to_csv
      verify_orchestration_outputs!(orchestration)
      stage_orchestration_inputs(orchestration)
      run_children(orchestration, :to_csv)
    when :to_sql
      verify_child_stage_files!(orchestration, WorkflowPaths::NORMALIZED_DIR)
      run_children(orchestration, :to_sql)
    when :drop_table
      run_children(orchestration, :drop_table)
    when :create_table
      verify_child_stage_files!(orchestration, WorkflowPaths::SQL_MAP_DIR, extension: '.sql')
      run_children(orchestration, :create_table)
    when :dump_sql
      run_children(orchestration, :dump_sql)
    when :use_sql
      verify_child_stage_files!(orchestration, WorkflowPaths::SQL_SCHEMA_DIR, extension: '.sql')
      run_children(orchestration, :use_sql)
    when :use_dsl
      verify_child_stage_files!(orchestration, WorkflowPaths::NORMALIZED_DIR)
      run_children(orchestration, :use_dsl)
    when :inject
      verify_child_stage_files!(orchestration, WorkflowPaths::APPLIED_DIR)
      run_tracked_injection(orchestration)
    else
      raise "unsupported orchestration stage: #{stage}"
    end
  end

  def run_orchestrated_refresh(selector)
    name, cfg = orchestration_entry(selector)
    orchestration = resolved_orchestration(name, cfg.fetch(:orchestration))
    return run_orchestration_stages(selector, %i[download to_csv use_dsl inject]) unless orchestration[:queue]

    drain_orchestration_queue(selector, orchestration)
  end

  def run_orchestrated_setup(selector)
    run_orchestration_stages(selector, %i[download to_csv to_sql use_dsl])
  end

  def run_orchestrated_oneshot(selector)
    run_orchestration_stages(selector, %i[download to_csv to_sql use_dsl create_table inject])
  end

  def run_setup(selector)
    return run_orchestrated_setup(selector) if orchestrated?(selector)

    run_standard_stages(selector, %i[download to_csv to_sql use_dsl])
  end

  def run_oneshot(selector)
    return run_orchestrated_oneshot(selector) if orchestrated?(selector)

    run_standard_stages(selector, %i[download to_csv to_sql use_dsl create_table inject])
  end

  def reset_stage_or_orchestration(selector)
    return reset_staged_files(selector) unless orchestrated?(selector)

    name, cfg = orchestration_entry(selector)
    orchestration = resolved_orchestration(name, cfg.fetch(:orchestration))
    run_postprocessing(orchestration)
    orchestration_children(orchestration).map(&:first).each do |child_name|
      reset_staged_files(child_name)
    end
  end

  def run_orchestration_stages(selector, stages)
    stages.each { |stage| run_orchestration_stage(selector, stage) }
  end
  private_class_method :run_orchestration_stages

  def drain_orchestration_queue(selector, orchestration)
    processed = 0
    while (entry = next_queue_entry(orchestration.fetch(:queue)))
      ensure_queue_entry_not_processed!(orchestration, entry)
      puts "[QUEUE] Processing #{entry}"
      run_orchestration_stages(selector, %i[download to_csv use_dsl inject])
      processed += 1
      next unless next_queue_entry(orchestration.fetch(:queue)) == entry

      raise "orchestration queue item was not removed: #{entry}"
    end
    puts "[QUEUE] Processed #{processed} item(s)"
  end
  private_class_method :drain_orchestration_queue

  def ensure_queue_entry_not_processed!(orchestration, entry)
    match = entry.match(/\AMail\.dat_(\d{8,9})\.zip\z/i)
    return unless match

    processed = File.absolute_path(orchestration.fetch(:processed_path).to_s,
                                   orchestration.fetch(:root_path))
    archive = File.join(processed, match[1])
    raise "duplicate OMS number: archive already exists: #{archive}" if Dir.exist?(archive)
  end
  private_class_method :ensure_queue_entry_not_processed!

  def next_queue_entry(queue)
    path = queue.fetch(:path)
    raise "orchestration queue directory not found: #{path}" unless Dir.exist?(path)

    Dir.children(path).sort.find do |entry|
      File.file?(File.join(path, entry)) && queue.fetch(:pattern).match?(entry)
    end
  end
  private_class_method :next_queue_entry

  def run_standard_stages(selector, stages)
    stages.each do |stage|
      script = stage == :download ? 'download.rb' : ORCHESTRATED_SCRIPTS.fetch(stage)
      run_ruby_stage(script, selector, log_selectors: log_selectors(stage, selector))
    end
  end
  private_class_method :run_standard_stages

  def orchestration_entry(selector)
    return nil if selector.nil?

    load_dsl_helpers
    selected = EtlHelpers.selected_dsl_entries(DSL_MAP, [selector]).select do |_name, cfg|
      cfg[:orchestration].is_a?(Hash)
    end
    raise "selector #{selector.inspect} matches multiple orchestrators" if selected.length > 1

    selected.first
  end
  private_class_method :orchestration_entry

  def resolved_orchestration(name, raw)
    root_path = File.expand_path(raw.fetch(:root_path).to_s)
    context = orchestration_context(raw, root_path)

    raw.merge(
      root_path: root_path,
      output_dir: context.fetch(:output_path),
      queue: resolve_queue_config(raw[:queue], context),
      preprocessing: resolve_lifecycle_config(name, :preprocessing, raw[:preprocessing], context),
      postprocessing: resolve_lifecycle_config(name, :postprocessing, raw[:postprocessing], context)
    )
  end
  private_class_method :resolved_orchestration

  def orchestration_context(raw, root_path)
    context = { root_path: root_path }
    %i[sent_path output_path processed_path].each do |key|
      context[key] = File.absolute_path(raw.fetch(key).to_s, root_path)
    end
    context
  end
  private_class_method :orchestration_context

  def resolve_queue_config(config, context)
    return nil unless config

    pattern = config.fetch(:pattern)
    pattern = Regexp.new(pattern.to_s) unless pattern.is_a?(Regexp)
    config.merge(path: resolve_argument(config.fetch(:path), context), pattern: pattern)
  end
  private_class_method :resolve_queue_config

  def resolve_lifecycle_config(name, phase, config, context)
    return nil if config.nil? || config[:enabled] == false

    directory = LIFECYCLE_DIRECTORIES.fetch(phase)
    script = File.join('script/ruby/data_runner/orchestration', directory, "#{dsl_slug(name)}.rb")
    config.merge(path: script, args: Array(config[:args]).map { |arg| resolve_argument(arg, context) })
  end
  private_class_method :resolve_lifecycle_config

  def dsl_slug(name)
    name.to_s.gsub(/([a-z\d])([A-Z])/, '\1_\2').downcase
  end
  private_class_method :dsl_slug

  def resolve_argument(value, context)
    value.is_a?(Symbol) ? context.fetch(value) : value.to_s
  rescue KeyError => e
    raise "unknown orchestration argument: #{e.key}"
  end
  private_class_method :resolve_argument

  def run_preprocessing(name, orchestration)
    config = orchestration[:preprocessing]
    return if config.nil?

    path = config[:path].to_s
    run_ruby_stage(path, *config.fetch(:args), log_selectors: [name])
  end
  private_class_method :run_preprocessing

  def orchestration_children(orchestration)
    orchestration.fetch(:children).map do |child_name|
      [child_name, dsl_config(child_name)]
    end
  end
  private_class_method :orchestration_children

  def dsl_config(name)
    load_dsl_helpers
    DSL_MAP.fetch(name) { raise "orchestration child DSL not found: #{name}" }
  end
  private_class_method :dsl_config

  def child_local!(child_name, child_cfg)
    local = EtlHelpers.source_local(child_cfg).to_s
    raise "#{child_name}: missing source.local" if local.empty?
    raise "#{child_name}: source.local must be a filename" unless File.basename(local) == local

    local
  end
  private_class_method :child_local!

  def verify_orchestration_outputs!(orchestration)
    missing = orchestration_children(orchestration).filter_map do |child_name, child_cfg|
      local = child_local!(child_name, child_cfg)
      path = File.join(orchestration.fetch(:output_dir), local)
      "#{child_name}: #{path}" unless File.file?(path)
    end
    return if missing.empty?

    raise "orchestration outputs missing:\n  #{missing.join("\n  ")}"
  end
  private_class_method :verify_orchestration_outputs!

  def stage_orchestration_inputs(orchestration)
    orchestration_children(orchestration).each do |child_name, child_cfg|
      local = child_local!(child_name, child_cfg)
      source = File.join(orchestration.fetch(:output_dir), local)
      target = File.join(WorkflowPaths::DOWNLOAD_DIR, local)
      FileUtils.mkdir_p(File.dirname(target))
      FileUtils.cp(source, target)
      puts "[STAGE] #{child_name}: #{source} -> #{target}"
    end
  end
  private_class_method :stage_orchestration_inputs

  def verify_child_stage_files!(orchestration, stage_dir, extension: nil)
    missing = orchestration_children(orchestration).filter_map do |child_name, child_cfg|
      filename = extension ? "#{EtlHelpers.base_for(child_cfg)}#{extension}" : EtlHelpers.output_for(child_cfg)
      path = File.join(stage_dir, filename)
      "#{child_name}: #{path}" unless File.file?(path)
    end
    return if missing.empty?

    raise "orchestration stage files missing:\n  #{missing.join("\n  ")}"
  end
  private_class_method :verify_child_stage_files!

  def run_children(orchestration, stage)
    script = ORCHESTRATED_SCRIPTS.fetch(stage)
    children = orchestration_children(orchestration).map(&:first)
    queue = Queue.new
    children.each { |child_name| queue << child_name }
    failures = Queue.new

    [children.length, ORCHESTRATION_CONCURRENCY].min.times.map do
      Thread.new do
        loop do
          child_name = queue.pop(true)
          begin
            run_orchestrated_child(script, child_name)
          rescue SystemExit, StandardError => e
            failures << [child_name, e]
          end
        rescue ThreadError
          break
        end
      end
    end.each(&:join)

    return if failures.empty?

    messages = []
    messages << failures.pop until failures.empty?
    details = messages.sort_by(&:first).map { |child_name, error| "#{child_name}: #{error.message}" }
    raise "orchestration #{stage} failures:\n  #{details.join("\n  ")}"
  end

  def run_orchestrated_child(script, child_name)
    environment = { Workflow::ORCHESTRATION_ENV => '1' }
    run_ruby_stage(script, child_name, log_selectors: [child_name], environment: environment)
  end
  private_class_method :run_orchestrated_child
  private_class_method :run_children

  def run_tracked_validation(name, orchestration)
    upload = orchestration_upload(orchestration)
    upload&.update!(status: 'validating', validation_status: 'running',
                    validation_started_at: Time.current, failure_message: nil)
    run_preprocessing(name, orchestration)
    verify_orchestration_outputs!(orchestration)
    upload&.update!(status: 'ready', validation_status: 'passed', validated_at: Time.current)
  rescue StandardError, SystemExit => e
    upload&.update!(status: 'needs_attention', validation_status: 'failed',
                    failed_at: Time.current, failure_message: e.message)
    raise
  end
  private_class_method :run_tracked_validation

  def run_tracked_injection(orchestration)
    upload = orchestration_upload(orchestration)
    upload&.begin_import!
    orchestration[:atomic_inject] ? run_atomic_inject(orchestration) : run_children(orchestration, :inject)
    upload&.update!(status: 'archiving', import_status: 'imported', imported_at: Time.current,
                    archive_status: 'archiving')
    run_postprocessing(orchestration)
    mark_files_archived(upload, orchestration)
    upload&.update!(status: 'completed', archive_status: 'archived', archived_at: Time.current)
  rescue StandardError, SystemExit => e
    failure = { status: 'failed', failed_at: Time.current, failure_message: e.message }
    failure[:import_status] = 'failed' unless upload&.import_status == 'imported'
    failure[:archive_status] = 'failed' if upload&.import_status == 'imported'
    upload&.update!(failure)
    raise
  end
  private_class_method :run_tracked_injection

  def orchestration_upload(orchestration)
    queue = orchestration[:queue]
    entry = queue && next_queue_entry(queue)
    match = entry&.match(/\AMail\.dat_(\d{8,9})\.zip\z/i)
    return unless match

    marker = Pathname.new(queue.fetch(:path)).join(entry)
    P2m::OmsUpload.find_by(oms_number: match[1], mailer_date: marker.mtime.to_date)
  end
  private_class_method :orchestration_upload

  def mark_files_archived(upload, orchestration)
    return unless upload

    processed = File.absolute_path(orchestration.fetch(:processed_path).to_s,
                                   orchestration.fetch(:root_path))
    archived_at = Time.current
    upload.files.each do |file|
      file.update!(archived_path: File.join(processed, upload.oms_number, file.original_filename), archived_at: archived_at)
    end
  end
  private_class_method :mark_files_archived

  def run_atomic_inject(orchestration)
    children = orchestration_children(orchestration).map(&:first)
    environment = {
      Workflow::ORCHESTRATION_ENV => '1',
      'DATARUNNER_ATOMIC_INJECT' => '1'
    }
    run_ruby_stage('inject.rb', *children, log_selectors: children, environment: environment)
  end
  private_class_method :run_atomic_inject

  def run_postprocessing(orchestration)
    config = orchestration[:postprocessing]
    return if config.nil?

    path = config[:path].to_s
    run_ruby_stage(path, *config.fetch(:args))
  end
  private_class_method :run_postprocessing
end
# rubocop:enable Metrics/ModuleLength
