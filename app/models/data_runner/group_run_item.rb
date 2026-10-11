# frozen_string_literal: true

module DataRunner
  class GroupRunItem < ApplicationRecord
    self.table_name = 'data_runner_group_run_items'

    STATUSES = %w[pending running succeeded failed].freeze

    belongs_to :group_run, class_name: 'DataRunner::GroupRun', inverse_of: :items

    validates :dsl_name, :dsl_slug, :status, :position, presence: true
    validates :status, inclusion: { in: STATUSES }

    def self.record_step(item_id, step)
      where(id: item_id, status: 'running').update_all(current_step: step.to_s, updated_at: Time.current)
    end
  end
end
