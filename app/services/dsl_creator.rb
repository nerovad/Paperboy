# frozen_string_literal: true

class DslCreator
  class InvalidDsl < StandardError; end

  Target = Data.define(:host, :database, :schema, :dsl_name)

  def initialize(name:, commands:, directory: Rails.root.join("dsl"))
    @raw_name = name.to_s.strip
    @commands = Array(commands).map(&:to_s)
    @directory = Pathname(directory)
  end

  def create!
    validate!
    @directory.mkpath
    path = @directory.join("#{@target.dsl_name}.rb")
    path.open("wx") { |file| file.write(source) }
    DslCatalog.reload! if @directory == Rails.root.join("dsl")
    @target.dsl_name
  rescue Errno::EEXIST
    raise InvalidDsl, "DSL #{@target.dsl_name} already exists."
  end

  private

  def validate!
    @target = parse_target
    raise InvalidDsl, "Select at least one DataRunner command." if @commands.empty?

    unknown = @commands - RakeTaskCatalog.runnable
    raise InvalidDsl, "Unknown DataRunner commands: #{unknown.join(', ')}" if unknown.any?
  end

  def parse_target
    raise InvalidDsl, "DSL name is required." if @raw_name.empty?

    parts = @raw_name.split(".", -1)
    target = case parts.length
    when 1 then Target.new("GSASQL16", "GSABSS", "dbo", parts.first)
    when 4 then Target.new(*parts)
    else
               raise InvalidDsl, "Use dslname or server.database.namespace.dslname."
    end

    invalid_dsl_name = target.to_h.values.any?(&:empty?) || !target.dsl_name.match?(/\A[A-Za-z0-9_]+\z/)
    raise InvalidDsl, "DSL name must use letters, numbers, and underscores." if invalid_dsl_name

    target
  end

  def source
    <<~RUBY
      # frozen_string_literal: true

      [
        '#{display_name}',
        {
          steps: {
            enabled: true,
            manual_steps: Workflow::MANUAL_STEPS,
            scheduled: {
              frequency: :daily,
              steps: Workflow::SCHEDULED_STEPS
            }
          },
          source: {
            location: '/mnt/i/BUSINESS_SUPPORT/DataRunner/01_Download/#{@target.dsl_name}.csv',
            local: '#{@target.dsl_name}.csv',
            format: :csv,
            strategy: :copy
          },
          to_csv: {
            sheet: 0,
            header_row: 0,
            data_row: 1
          },
          header: [
          ],
          database_connections: [
            {
              host: #{ruby_literal(@target.host)},
              database: #{ruby_literal(@target.database)},
              schema: #{ruby_literal(@target.schema)},
              table: #{ruby_literal(@target.dsl_name)},
              inject: { mode: :truncate_insert }
            }
          ]
        }
      ]
    RUBY
  end

  def display_name
    @target.dsl_name.split("_").map(&:capitalize).join(" ")
  end

  def ruby_literal(value)
    "'#{value.to_s.gsub('\\', '\\\\\\').gsub("'", "\\\\'")}'"
  end
end
