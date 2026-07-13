# frozen_string_literal: true

ENV['RAILS_ENV'] ||= 'test'
require_relative '../config/environment'
require 'rails/test_help'

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Keep global fixtures to records used by active tests. Placeholder
    # lookup fixtures can overflow short SQL Server string primary keys.
    fixtures :probation_transfer_requests

    # Add more helper methods to be used by all tests here...
  end
end
