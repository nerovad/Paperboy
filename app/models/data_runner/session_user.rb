# frozen_string_literal: true

module DataRunner
  class SessionUser
    include ActiveModel::Model

    attr_accessor :employee_id, :email, :first_name, :last_name

    def full_name
      [ first_name, last_name ].compact.join(" ").strip
    end
  end
end
