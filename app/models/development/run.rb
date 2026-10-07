# frozen_string_literal: true

module Development
  class Run < ApplicationRecord
    self.table_name = 'development_runs'

    STATUSES = %w[queued running succeeded failed].freeze

    validates :status, inclusion: { in: STATUSES }
    validates :script_key, :script_label, :requested_by, presence: true

    def command
      JSON.parse(command_json)
    rescue JSON::ParserError
      []
    end

    def command=(value)
      self.command_json = Array(value).to_json
    end

    def finished?
      %w[succeeded failed].include?(status)
    end
  end
end
