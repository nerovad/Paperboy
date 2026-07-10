#!/usr/bin/env ruby
# frozen_string_literal: true

require 'fileutils'

DSL_DIR = File.join(__dir__, '../..', 'dsl')
StubTarget = Struct.new(:host, :database, :schema, :dsl_name, keyword_init: true)

def usage!
  abort 'Usage: rake DataRunner:dsl_stub name_of_stub | host.database.schema.dsl_name'
end

def valid_dsl_name?(name)
  name.match?(/\A[A-Za-z0-9_]+\z/)
end

def stub_target(raw_name)
  value = raw_name.to_s.strip
  usage! if value.empty?

  parts = value.split('.', -1)
  target = case parts.length
  when 1
             StubTarget.new(host: 'GSASQL16', database: 'GSABSS', schema: 'dbo', dsl_name: parts.first)
  when 4
             StubTarget.new(host: parts[0], database: parts[1], schema: parts[2], dsl_name: parts[3])
  else
             usage!
  end

  abort 'Stub target segments must not be empty' if target.to_h.values.any?(&:empty?)
  abort 'Stub name must use letters, numbers, and underscores only' unless valid_dsl_name?(target.dsl_name)

  target
end

def dataset_key(name)
  name.sub(/\A./, &:upcase)
end

def single_quoted(value)
  "'#{value.to_s.gsub('\\', '\\\\\\').gsub("'", "\\\\'")}'"
end

def empty_header_block
  [
    'header: [',
    '    ]'
  ].join("\n")
end

def render_stub(target)
  name = target.dsl_name
  key = dataset_key(name)
  quoted_name = single_quoted(name)
  quoted_csv = single_quoted("#{name}.csv")
  quoted_location = single_quoted("/mnt/i/BUSINESS_SUPPORT/DataRunner/01_Download/#{name}.csv")

  <<~RUBY
    # frozen_string_literal: true

    [
      #{single_quoted(key)},
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
          location: #{quoted_location},
          local: #{quoted_csv},
          format: :csv,
          strategy: :copy
        },
        to_csv: {
          sheet: 0,
          header_row: 0,
          data_row: 1
        },
        #{empty_header_block},
        database_connections: [
          {
            host: #{single_quoted(target.host)},
            database: #{single_quoted(target.database)},
            schema: #{single_quoted(target.schema)},
            table: #{quoted_name},
            inject: {
              mode: :truncate_insert
            }
          }
        ]
      }
    ]
  RUBY
end

if __FILE__ == $PROGRAM_NAME
  target = stub_target(ARGV.first)
  name = target.dsl_name
  path = File.join(DSL_DIR, "#{name}.rb")

  abort "[FAIL] #{path} already exists" if File.exist?(path)

  FileUtils.mkdir_p(DSL_DIR)
  File.write(path, render_stub(target))
  puts "[OK] Created dsl/#{File.basename(path)}"
end
