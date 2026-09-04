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
    DESTROYED = ENV.fetch('P2M_DESTROYED')
    PRINTERS = ENV.fetch('P2M_PRINTERS')

    STAGING_PATH = DATA_RUNNER_ROOT.join(STAGING)
    SHIPPING_STATION_PATH = DATA_RUNNER_ROOT.join(SHIPPING_STATION)
    PROCESSED_PATH = DATA_RUNNER_ROOT.join(PROCESSED)
    DESTROYED_PATH = Pathname.new(DESTROYED).then do |path|
      path.absolute? ? path : DATA_RUNNER_ROOT.join(path)
    end
    PRINTERS_PATH = Pathname.new(PRINTERS).then do |path|
      path.absolute? ? path : DATA_RUNNER_ROOT.join(path)
    end
  end
end
