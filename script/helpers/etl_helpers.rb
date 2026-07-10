# frozen_string_literal: true

# Shared helper methods for ETL stage scripts.
# rubocop:disable Metrics/ModuleLength
module EtlHelpers
  module_function

  DatabaseTarget = Struct.new(:host, :database, :schema, :table, :connection, keyword_init: true) do
    def label
      [ host, database, schema, table ].compact.map(&:to_s).reject(&:empty?).join('.')
    end
  end

  class RunStats
    attr_reader :success, :fail, :skipped

    def initialize
      @success = 0
      @fail = 0
      @skipped = 0
    end

    def ok!
      @success += 1
    end

    def fail!
      @fail += 1
    end

    def skip!
      @skipped += 1
    end

    def summary
      "Summary: #{@success} succeeded, #{@fail} failed, #{@skipped} skipped"
    end
  end

  def output_for(cfg)
    out = cfg[:output]
    return out if out && !out.to_s.strip.empty?

    src = cfg[:source] || {}
    local = src[:local].to_s
    base = File.basename(local, File.extname(local))
    "#{base}.csv"
  end

  def base_for(cfg)
    File.basename(output_for(cfg), '.csv')
  end

  def sql_table(cfg, database_connection = nil)
    dbc = database_connection || cfg[:database_connection] || {}
    t = dbc[:table].to_s.strip
    t = cfg[:table].to_s.strip if t.empty?
    return t unless t.empty?

    base_for(cfg)
  end

  def sql_schema(cfg, database_connection = nil)
    dbc = database_connection || cfg[:database_connection] || {}
    s = dbc[:schema].to_s.strip
    s = cfg[:schema].to_s.strip if s.empty?
    s.empty? ? 'dbo' : s
  end

  def sql_database(cfg, database_connection = nil, env_database: nil)
    dbc = database_connection || cfg[:database_connection] || {}
    db = dbc[:database].to_s.strip
    db = cfg[:database].to_s.strip if db.empty?
    db = env_database.to_s.strip if db.empty? && !env_database.nil?
    db
  end

  def sql_host(cfg, database_connection = nil, env_host: nil)
    dbc = database_connection || cfg[:database_connection] || {}
    host = dbc[:host].to_s.strip
    host = cfg[:host].to_s.strip if host.empty?
    host = env_host.to_s.strip if host.empty? && !env_host.nil?
    host
  end

  def database_targets(cfg, env_host: nil, env_database: nil)
    connections = database_connections(cfg)
    connections = [ {} ] if connections.empty?

    connections.map do |connection|
      DatabaseTarget.new(
        host: sql_host(cfg, connection, env_host: env_host),
        database: sql_database(cfg, connection, env_database: env_database),
        schema: sql_schema(cfg, connection),
        table: sql_table(cfg, connection),
        connection: connection
      )
    end
  end

  def database_connections(cfg)
    raw = cfg[:database_connections]
    connections =
      if raw.nil?
        []
      elsif raw.is_a?(Array)
        raw
      else
        [ raw ]
      end

    connections = connections.map { |entry| normalize_database_connection(entry) }
                             .reject(&:empty?)
    return connections unless connections.empty?

    legacy = cfg[:database_connection]
    legacy.nil? ? [] : [ normalize_database_connection(legacy) ]
  end

  def normalize_database_connection(entry)
    return {} if entry.nil?

    if entry.is_a?(Hash) && entry.key?(:database_connection)
      entry[:database_connection] || {}
    else
      entry
    end
  end

  def normalized_output_name(output)
    return '' if output.nil?

    o = output.to_s.strip
    return '' if o.empty? || o.casecmp('nil').zero?

    o
  end

  def source(cfg)
    cfg[:source] || {}
  end

  def source_local(cfg)
    source(cfg)[:local]
  end

  def source_location(cfg)
    source(cfg)[:location] || source(cfg)[:local]
  end

  def source_format(cfg)
    source(cfg)[:format]&.to_sym
  end

  def source_strategy(cfg, default = :http)
    (source(cfg)[:strategy] || cfg[:strategy] || default).to_sym
  end

  def output_name_index(dsl_map)
    index = {}
    dsl_map.each do |name, cfg|
      index[output_for(cfg)] = name
    end
    index
  end

  def single_stage_arg(argv)
    args = argv.compact.map(&:to_s).reject(&:empty?)
    raise "expected at most one argument, got #{args.length}" if args.length > 1

    args.first
  end

  def dsl_entry_matches?(selector, name, cfg)
    wanted = File.basename(selector, File.extname(selector)).downcase
    candidates = [
      name,
      cfg[:group].is_a?(Hash) ? cfg[:group][:name] : cfg[:group],
      base_for(cfg),
      output_for(cfg),
      source_local(cfg),
      File.basename(source_local(cfg).to_s, File.extname(source_local(cfg).to_s))
    ].compact.map(&:to_s).reject(&:empty?)

    candidates.any? do |candidate|
      candidate.downcase == selector.downcase ||
        File.basename(candidate, File.extname(candidate)).downcase == wanted
    end
  end

  def selected_dsl_entries(dsl_map, argv)
    selector = single_stage_arg(argv)
    return dsl_map if selector.nil?

    selected = dsl_map.select { |name, cfg| dsl_entry_matches?(selector, name, cfg) }
    raise "unknown DSL: #{selector}" if selected.empty?

    selected
  end

  def resolve_stage_inputs(argv, stage_dir, dsl_map)
    selected_dsl_entries(dsl_map, argv).values
                                       .map { |cfg| output_for(cfg) }
                                       .uniq
                                       .map do |f|
      File.join(
        stage_dir, f
      )
    end
  end
end
# rubocop:enable Metrics/ModuleLength
