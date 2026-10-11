# frozen_string_literal: true

require 'minitest/autorun'
require_relative '../../script/ruby/data_runner/constants/workflow'
require_relative '../../script/ruby/data_runner/helpers/bcp_stage'

class SolidSchemaDslTest < Minitest::Test
  DSL_DIR = File.expand_path('../../config/data_runner/dsl/paperboy_dev', __dir__)

  JOB_REFERENCE = { column: 'job_id', table: 'solid_queue_jobs' }.freeze

  CHILD_REFERENCES = {
    'paperboy_dev_solid_queue_batch_executions.rb' => [
      JOB_REFERENCE,
      { column: 'batch_id', table: 'solid_queue_batches' }
    ],
    'paperboy_dev_solid_queue_blocked_executions.rb' => [JOB_REFERENCE],
    'paperboy_dev_solid_queue_claimed_executions.rb' => [JOB_REFERENCE],
    'paperboy_dev_solid_queue_failed_executions.rb' => [JOB_REFERENCE],
    'paperboy_dev_solid_queue_ready_executions.rb' => [JOB_REFERENCE],
    'paperboy_dev_solid_queue_recurring_executions.rb' => [JOB_REFERENCE],
    'paperboy_dev_solid_queue_scheduled_executions.rb' => [JOB_REFERENCE]
  }.freeze

  def test_queue_children_reference_the_generated_foreign_keys
    CHILD_REFERENCES.each do |file, references|
      config = load_config(file)

      assert_equal references, config[:references], file
      assert_includes Array(config[:dependency]), 'Paperboy_dev_solid_queue_jobs', file
    end
  end

  def test_batch_executions_also_waits_for_batches
    config = load_config('paperboy_dev_solid_queue_batch_executions.rb')

    assert_includes config[:dependency], 'Paperboy_dev_solid_queue_batches'
  end

  def test_cable_and_cache_keep_the_generated_varbinary_columns
    cable = load_config('paperboy_dev_solid_cable_messages.rb')
    cache = load_config('paperboy_dev_solid_cache_entries.rb')

    assert_includes cable[:header], ['channel', 'channel', 'varbinary(max)', 'NOT NULL', nil]
    assert_includes cable[:header], ['payload', 'payload', 'varbinary(max)', 'NOT NULL', nil]
    assert_includes cache[:header], ['key', 'key', 'varbinary(max)', 'NOT NULL', nil]
    assert_includes cache[:header], ['value', 'value', 'varbinary(max)', 'NOT NULL', nil]
    assert_nil cable[:references]
    assert_nil cache[:references]
  end

  def test_publish_restores_varbinary_max_and_drops_unloaded_job_ids
    insert = DataRunner::BcpStage.insert_sql(
      'pb', 'solid_cable_messages', 'solid_cable_messages_bcp_ab12',
      %w[channel payload],
      {
        'channel' => { data_type: 'varbinary(max)', nullability: 'NOT NULL' },
        'payload' => { data_type: 'varbinary(max)', nullability: 'NOT NULL' }
      }
    )
    delete = DataRunner::BcpStage.missing_parent_delete_sql(
      'pb', 'solid_queue_recurring_executions_bcp_ab12',
      'solid_queue_jobs', 'job_id', 'id', 'bigint'
    )

    assert_includes insert, 'CONVERT(varbinary(max), NULLIF(stage.[channel], N\'\'), 2)'
    assert_includes insert, 'CONVERT(varbinary(max), NULLIF(stage.[payload], N\'\'), 2)'
    assert_equal(
      'DELETE stage FROM [pb].[solid_queue_recurring_executions_bcp_ab12] AS stage ' \
      'WHERE NOT EXISTS (SELECT 1 FROM [pb].[solid_queue_jobs] AS parent ' \
      'WHERE parent.[id] = TRY_CONVERT(bigint, stage.[job_id]))',
      delete
    )
  end

  private

  def load_config(file)
    entry = TOPLEVEL_BINDING.eval(File.read(File.join(DSL_DIR, file)), file)
    entry[1]
  end
end
