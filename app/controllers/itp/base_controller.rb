# frozen_string_literal: true

module Itp
  # Base controller for the IT Portal app. Every IT Portal controller should
  # inherit from this so the ACL gate below is applied consistently.
  class BaseController < ApplicationController
    include ApplicationAccessGate

    gate_application 'itp', label: 'IT Portal'
  end
end
