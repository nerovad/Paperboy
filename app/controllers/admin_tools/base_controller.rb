# frozen_string_literal: true

module AdminTools
  # Base controller for the Admin Tools app. Every Admin Tools controller should
  # inherit from this so the ACL gate below is applied consistently.
  class BaseController < ApplicationController
    include ApplicationAccessGate

    gate_application 'admin_tools', label: 'Admin Tools'
  end
end
