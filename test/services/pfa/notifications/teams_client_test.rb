# frozen_string_literal: true

require 'test_helper'

module Pfa
  module Notifications
    class TeamsClientTest < ActiveSupport::TestCase
      test 'posts JSON to the configured webhook' do
        response = Net::HTTPOK.new('1.1', '200', 'OK')
        http = fake_http(response)

        Net::HTTP.stub(:new, http) do
          assert TeamsClient.new('https://teams.example.test/hook').post(message: 'Hello')
        end

        assert_equal '/hook', http.request_object.path
        assert_equal 'application/json', http.request_object['Content-Type']
        assert_equal({ 'message' => 'Hello' }, JSON.parse(http.request_object.body))
      end

      private

      def fake_http(response)
        Object.new.tap do |http|
          http.define_singleton_method(:use_ssl=) { |_value| nil }
          http.define_singleton_method(:read_timeout=) { |_value| nil }
          http.define_singleton_method(:open_timeout=) { |_value| nil }
          http.define_singleton_method(:request_object) { @request }
          http.define_singleton_method(:request) do |request|
            @request = request
            response
          end
        end
      end
    end
  end
end
