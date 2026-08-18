# frozen_string_literal: true

module DataRunner
  class GroupRun < ApplicationRecord
    self.table_name = 'data_runner_group_runs'

    ACTIVE_STATUSES = %w[queued running].freeze
    STATUSES = (ACTIVE_STATUSES + %w[succeeded failed]).freeze

    has_many :items, class_name: 'DataRunner::GroupRunItem', dependent: :destroy,
                     inverse_of: :group_run

    validates :run_id, :group_name, :status, presence: true
    validates :run_id, uniqueness: true
    validates :status, inclusion: { in: STATUSES }

    scope :active, -> { where(status: ACTIVE_STATUSES) }

    def active? = status.in?(ACTIVE_STATUSES)
    def finished? = !active?
  end
end
