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

  def self.step_config(cfg)
    configured = cfg[:steps]
    return configured if configured.is_a?(Hash)

    {
      enabled: true,
      manual_steps: cfg[:manual_steps] || configured,
      scheduled: cfg[:scheduled]
    }
  end

  def self.steps_enabled?(cfg)
    step_config(cfg).fetch(:enabled, true) != false
  end

  def self.wants_step?(cfg, step)
    return false unless steps_enabled?(cfg)

    steps = step_config(cfg)[:manual_steps] || MANUAL_STEPS
    steps.include?(step)
  end

  def self.wants_scheduled_step?(cfg, step, frequency = nil)
    return false unless steps_enabled?(cfg)

    scheduled = step_config(cfg)[:scheduled]
    return false unless scheduled

    scheduled_frequency = scheduled[:frequency] || :daily
    return false if frequency && scheduled_frequency != frequency

    steps = scheduled[:steps] || SCHEDULED_STEPS
    steps.include?(step)
  end
end

# -------------------------------------------------------------------------- }}}
