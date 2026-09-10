# frozen_string_literal: true

module HsaAdoptionCards
  # Base for everything this app raises on purpose. Each carries a message
  # written for the person at the screen; +detail+ keeps the underlying
  # error text for the smaller print beneath it.
  class Error < StandardError
    attr_reader :detail

    def initialize(message, detail: nil)
      super(message)
      @detail = detail.presence
    end
  end
end
