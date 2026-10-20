# frozen_string_literal: true

module Development
  class BaseController < ::ApplicationController
    include ApplicationAccessGate

    gate_application 'development', label: 'Development'
  end
end
