# frozen_string_literal: true

module DataRunner
  class Current < ActiveSupport::CurrentAttributes
    attribute :user
  end
end
