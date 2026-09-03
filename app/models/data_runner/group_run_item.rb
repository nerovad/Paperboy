# frozen_string_literal: true

module DataRunner
  class GroupRunItem < ApplicationRecord
    self.table_name = 'data_runner_group_run_items'

    STATUSES = %w[pending running succeeded failed].freeze

    belongs_to :group_run, class_name: 'DataRunner::GroupRun', inverse_of: :items

    validates :dsl_name, :dsl_slug, :status, :position, presence: true
    validates :status, inclusion: { in: STATUSES }
  end
end
