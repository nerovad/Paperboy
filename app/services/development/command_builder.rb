# frozen_string_literal: true

module Development
  class CommandBuilder
    def initialize(script, arguments)
      @script = script
      @arguments = arguments
    end

    def program = Rails.root.join('bin', @script.fetch(:bin)).to_s

    def call
      [program, *@arguments]
    end

    alias to_a call
  end
end
