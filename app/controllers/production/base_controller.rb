# frozen_string_literal: true

module Production
  # Base controller for the Production app. Every Production controller should
  # inherit from this so the ACL gate below is applied consistently.
  class BaseController < ApplicationController
    include ApplicationAccessGate

    gate_application 'print_production', label: 'Production'
  end
end
