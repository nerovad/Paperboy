# frozen_string_literal: true

module Dam
  # Stands in for Dam::Publishing::Http so the adapter tests can watch what a
  # publish would have sent without anything leaving the machine.
  #
  # Responses are handed out in the order they were given, which is enough:
  # every one of these flows is a fixed sequence of requests, and a test that
  # cares which is which asserts on the recorded call.
  class FakePublishingHttp
    Call = Struct.new(:verb, :url, :options, keyword_init: true)

    attr_reader :calls

    def initialize(*responses)
      @responses = responses.flatten
      @calls = []
    end

    def self.response(code: 200, body: {}, headers: {})
      Dam::Publishing::Http::Response.new(code: code, body: body.is_a?(String) ? body : body.to_json,
                                          headers: headers)
    end

    def get(url, headers: {}) = record(:get, url, headers: headers)

    def delete(url, headers: {}) = record(:delete, url, headers: headers)

    def post_form(url, fields, headers: {}) = record(:post_form, url, fields: fields, headers: headers)

    def post_json(url, payload, headers: {}) = record(:post_json, url, payload: payload, headers: headers)

    def json_request(verb, url, payload, headers: {})
      record(:json_request, url, verb: verb, payload: payload, headers: headers)
    end

    def post_multipart(url, **options) = record(:post_multipart, url, **options)

    def send_file(verb, url, file, headers: {}, offset: 0, length: nil)
      record(:send_file, url, verb: verb, file: file, headers: headers, offset: offset, length: length)
    end

    def call(index) = calls[index]

    def urls = calls.map(&:url)

    private

    def record(verb, url, **options)
      @calls << Call.new(verb: verb, url: url, options: options)
      @responses.shift || self.class.response
    end
  end
end
