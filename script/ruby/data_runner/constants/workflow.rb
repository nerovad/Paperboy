#!/usr/bin/env ruby
# frozen_string_literal: true

# {{{ Requirements and definitions.

# ETL workflow steps.
module Workflow
  ALL_STEPS = %i[
    download
    to_csv
    to_sql
    drop_table
    create_table
    use_dsl
    inject
  ].freeze

  MANUAL_STEPS = ALL_STEPS

  SCHEDULED_STEPS = %i[
    download
    to_csv
    use_dsl
    inject
  ].freeze

  SCHEDULE_FREQUENCIES = %i[
    daily
    weekly
    monthly
  ].freeze

  ORCHESTRATION_ENV = 'DATA_RUNNER_ORCHESTRATION'

  def self.step_config(cfg)
    configured = cfg[:steps]
    return configured if configured.is_a?(Hash)

    {
      manual: {
        enabled: true,
        steps: configured || MANUAL_STEPS
      },
      scheduled: nil
    }
  end

  def self.steps_enabled?(cfg)
    manual = step_config(cfg).fetch(:manual)
    manual.fetch(:enabled, true) != false
  end

  def self.wants_step?(cfg, step)
    manual = step_config(cfg).fetch(:manual)
    enabled = manual.fetch(:enabled, true) || ENV[ORCHESTRATION_ENV] == '1'
    return false unless enabled

    steps = manual[:steps] || MANUAL_STEPS
    steps.include?(step)
  end

  def self.wants_scheduled_step?(cfg, step, frequency = nil)
    scheduled = step_config(cfg)[:scheduled]
    return false unless scheduled
    return false if scheduled[:enabled] == false

    scheduled_frequency = scheduled[:frequency] || :daily
    return false if frequency && scheduled_frequency != frequency

    steps = scheduled[:steps] || SCHEDULED_STEPS
    steps.include?(step)
  end
end

# -------------------------------------------------------------------------- }}}
