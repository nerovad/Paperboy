# frozen_string_literal: true

require 'dotenv/load'
require 'pathname'

module P2m
  module Paths
    DATA_RUNNER_ROOT = Pathname.new(ENV.fetch('P2M_DATARUNNER_ROOT'))
    STAGING = ENV.fetch('P2M_STAGING')
    SHIPPING_STATION = ENV.fetch('P2M_SHIPPING_STATION')
    TEMPORARY_OUTPUT = ENV.fetch('P2M_TEMPORARY_OUTPUT')
    PROCESSED = ENV.fetch('P2M_PROCESSED')

    STAGING_PATH = DATA_RUNNER_ROOT.join(STAGING)
    SHIPPING_STATION_PATH = DATA_RUNNER_ROOT.join(SHIPPING_STATION)
    PROCESSED_PATH = DATA_RUNNER_ROOT.join(PROCESSED)
  end
end
