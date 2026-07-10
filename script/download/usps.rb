#!/usr/bin/env ruby
# frozen_string_literal: true

require 'date'
require 'fileutils'
require 'net/http'
require 'pathname'
require 'uri'

require_relative '../commands/dsl_map'
require_relative '../helpers/etl_helpers'
require_relative '../constants/workflow_paths'

ROOT = Pathname.new(__dir__).parent.parent.expand_path
CFG = DSL_MAP.fetch('USPS')
DOWNLOAD_DIR = Pathname.new(WorkflowPaths::DOWNLOAD_DIR)
OUTPUT_PATH = DOWNLOAD_DIR.join(EtlHelpers.source_local(CFG).to_s)

REQUIRED_ENV = %w[
  USPS_PASSWORD
  USPS_USERNAME
  USPS_SIGNON_URL
  USPS_STEP_01
  USPS_STEP_02
  USPS_STEP_03
  USPS_STEP_04
  USPS_STEP_05
  USPS_STEP_06
].freeze

RequestSpec = Struct.new(:verb, :uri, :body, keyword_init: true)

def load_dotenv(path = ROOT.join('.env'))
  return unless path.file?

  path.each_line do |line|
    key, value = parse_env_line(line)
    next if key.nil? || ENV.key?(key)

    ENV[key] = value
  end
end

def parse_env_line(line)
  stripped = line.strip
  return nil if stripped.empty? || stripped.start_with?('#')
  return nil unless stripped.include?('=')

  key, value = stripped.split('=', 2)
  [ key.strip, unquote(value.strip) ]
end

def unquote(value)
  if (value.start_with?('"') && value.end_with?('"')) ||
     (value.start_with?("'") && value.end_with?("'"))
    value[1..-2]
  else
    value
  end
end

def required_env!
  missing = REQUIRED_ENV.select { |key| ENV[key].to_s.strip.empty? }
  return if missing.empty?

  raise "missing ENV: #{missing.join(', ')}"
end

def previous_month_range(today = Date.today)
  first = Date.new(today.year, today.month, 1) << 1
  last = Date.new(today.year, today.month, 1) - 1

  [ first, last ]
end

def substitutions
  start_date, end_date = previous_month_range
  {
    'USPS_USERNAME' => ENV.fetch('USPS_USERNAME'),
    'USPS_PASSWORD' => ENV.fetch('USPS_PASSWORD'),
    'START_DATE' => start_date.iso8601,
    'END_DATE' => end_date.iso8601
  }
end

def expand_placeholders(value)
  substitutions.reduce(value.to_s) do |expanded, (key, replacement)|
    expanded.gsub("{#{key}}", replacement)
            .gsub("${#{key}}", replacement)
  end
end

def uri_from_url(raw_url)
  URI.parse(raw_url)
rescue URI::InvalidURIError
  URI.parse(URI::DEFAULT_PARSER.escape(raw_url))
end

def request_spec(raw_spec, default_method: :get)
  spec = expand_placeholders(raw_spec).strip
  verb = default_method

  if spec.match?(/\A(GET|POST)\s+/i)
    verb, spec = spec.split(/\s+/, 2)
    verb = verb.downcase.to_sym
  end

  url, body = spec.split(/\s+/, 2)
  uri = uri_from_url(url.to_s)
  raise "request is not HTTP URL: #{raw_spec}" unless uri.is_a?(URI::HTTP)

  RequestSpec.new(verb: verb, uri: uri, body: body)
end

def cookie_header(cookies)
  cookies.map { |key, value| "#{key}=#{value}" }.join('; ')
end

def store_cookies(cookies, response)
  response.get_fields('set-cookie').to_a.each do |header|
    pair = header.split(';', 2).first
    key, value = pair.split('=', 2)
    cookies[key] = value unless key.to_s.empty?
  end
end

def build_request(spec, cookies)
  klass = spec.verb == :post ? Net::HTTP::Post : Net::HTTP::Get
  request = klass.new(spec.uri)
  request['Cookie'] = cookie_header(cookies) unless cookies.empty?
  request['User-Agent'] = 'DataRunner USPS downloader'

  if spec.verb == :post
    request['Content-Type'] = 'application/x-www-form-urlencoded'
    request.body = spec.body.to_s
  end

  request
end

def perform_request(spec, cookies, redirect_limit: 10)
  raise "too many redirects while requesting #{spec.uri}" if redirect_limit.negative?

  http = Net::HTTP.new(spec.uri.host, spec.uri.port)
  http.use_ssl = spec.uri.scheme == 'https'
  response = http.request(build_request(spec, cookies))
  store_cookies(cookies, response)

  case response
  when Net::HTTPRedirection
    location = response['location'].to_s
    redirected_uri = uri_from_url(location)
    redirected_uri = spec.uri + location if redirected_uri.relative?
    redirected = RequestSpec.new(verb: :get, uri: redirected_uri)
    perform_request(redirected, cookies, redirect_limit: redirect_limit - 1)
  else
    response
  end
end

def request_specs
  signon_body = URI.encode_www_form(
    username: ENV.fetch('USPS_USERNAME'),
    password: ENV.fetch('USPS_PASSWORD')
  )
  signon = RequestSpec.new(
    verb: :post,
    uri: request_spec(ENV.fetch('USPS_SIGNON_URL')).uri,
    body: signon_body
  )
  steps = (1..6).map { |number| request_spec(ENV.fetch(format('USPS_STEP_%02d', number))) }

  [ signon, *steps ]
end

load_dotenv
required_env!

cookies = {}
response = nil
request_specs.each.with_index(1) do |spec, index|
  response = perform_request(spec, cookies)
  raise "USPS request #{index} failed: HTTP #{response.code}" unless response.is_a?(Net::HTTPSuccess)
end

FileUtils.mkdir_p(DOWNLOAD_DIR)
File.binwrite(OUTPUT_PATH, response.body)

puts "[OK] USPS postage downloaded -> #{OUTPUT_PATH}"
