# frozen_string_literal: true

module Development
  class CommandBuilder
    def initialize(script, arguments)
      @script = script
      @arguments = arguments
    end

    def call
      [Rails.root.join('bin', @script.fetch(:bin)).to_s, *@arguments]
    end

    alias to_a call
  end
end
