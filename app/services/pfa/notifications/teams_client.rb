# frozen_string_literal: true

require 'net/http'
require 'uri'

module Pfa
  module Notifications
    class TeamsClient
      def initialize(webhook_url, logger: Rails.logger)
        @uri = URI.parse(webhook_url)
        @logger = logger
      end

      def post(payload)
        response = http.request(request(payload))
        return response if response.is_a?(Net::HTTPSuccess)

        logger.error("Teams notification failed with HTTP #{response.code}: #{response.body}")
        nil
      end

      private

      attr_reader :uri, :logger

      def http
        Net::HTTP.new(uri.host, uri.port).tap do |client|
          client.use_ssl = uri.scheme == 'https'
          client.read_timeout = 10
          client.open_timeout = 5
        end
      end

      def request(payload)
        Net::HTTP::Post.new(uri.request_uri).tap do |request|
          request['Content-Type'] = 'application/json'
          request.body = payload.to_json
        end
      end
    end
  end
end
