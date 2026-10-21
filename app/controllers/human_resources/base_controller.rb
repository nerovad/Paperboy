# frozen_string_literal: true

module HumanResources
  # Base controller for the Human Resources app. Every Human Resources controller should
  # inherit from this so the application gate is applied consistently.
  class BaseController < ApplicationController
    include ApplicationAccessGate

    gate_application 'human_resources', label: 'Human Resources'
  end
end
