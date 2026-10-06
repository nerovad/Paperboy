#!/usr/bin/env ruby
# frozen_string_literal: true

# Stand-in for curl. Fixtures live in GITEA_FIXTURES as "<key>.json" envelopes:
#   {"status":200,"total":2,"body":[...]}
# The key is "METHOD path query page=N", with limit omitted and the query
# decoded. Requests are appended to CURL_LOG. The Authorization value is not.

require 'json'
require 'uri'

def fixture_key(method, url)
  uri = URI(url)
  relative = uri.path.sub(%r{.*/repos/[^/]+/[^/]+/}, '')
  params = URI.decode_www_form(uri.query.to_s).to_h
  page = params.delete('page') || '1'
  params.delete('limit')
  extra = params.sort.map { |key, value| "#{key}=#{value}" }.join('&')
  [method, relative, extra, "page=#{page}"].reject(&:empty?).join(' ')
end

args = ARGV.dup
method = 'GET'
url = nil
data = nil
outfile = nil
header_file = nil
auth = false

while (arg = args.shift)
  case arg
  when '-X'
    method = args.shift
  when '--data-binary', '--data'
    data = args.shift
  when '-o'
    outfile = args.shift
  when '-D'
    header_file = args.shift
  when '-w', '-H', '--connect-timeout', '--max-time'
    value = args.shift
    auth = true if arg == '-H' && value.to_s.start_with?('Authorization:')
  when '--silent', '--show-error', '--fail-with-body'
    next
  else
    url = arg if arg.start_with?('http')
  end
end

abort 'fake curl: no URL' if url.nil?

key = fixture_key(method, url)
log = ENV.fetch('CURL_LOG')
File.open(log, 'a') do |file|
  file.puts '---'
  file.puts "method=#{method}"
  file.puts "url=#{url}"
  file.puts "key=#{key}"
  file.puts "auth=#{auth ? 'yes' : 'no'}"
  file.puts "data=#{data}"
end

path = File.join(ENV.fetch('GITEA_FIXTURES'), "#{key.tr('/', '|')}.json")
unless File.file?(path)
  warn "fake curl: no fixture for #{key}"
  warn "fake curl: url #{url}"
  exit 1
end

envelope = JSON.parse(File.read(path))
status = envelope.fetch('status', 200).to_i
body = envelope.fetch('body')
total = envelope['total']
rendered = body.nil? ? '' : JSON.generate(body)

if header_file
  headers = ["HTTP/1.1 #{status} OK"]
  headers << "X-Total-Count: #{total}" unless total.nil?
  File.write(header_file, "#{headers.join("\n")}\n")
end

if outfile
  File.write(outfile, rendered)
else
  $stdout.write(rendered)
end
$stdout.write(status.to_s)
