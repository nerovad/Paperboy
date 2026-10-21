# frozen_string_literal: true

module Paperboy
  module Pdf
    # A PDF this toolkit cannot read or write: encrypted, malformed, or
    # holding something the writer has no form for.
    class Unwritable < StandardError; end
  end
end
