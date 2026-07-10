#!/usr/bin/env ruby
# frozen_string_literal: true

# {{{ Requirements and definitions.

require 'net/http'
require 'rbconfig'
require 'uri'
require 'fileutils'
require_relative 'dsl_map'
require_relative '../helpers/etl_helpers'
require_relative '../constants/workflow'
require_relative '../constants/workflow_paths'

ROOT = File.expand_path('../..', __dir__)
$LOAD_PATH.unshift(ROOT)

ACWEB_ROOT = 'http://acweb'
VCFMS_URL  = "#{ACWEB_ROOT}/index.php/vcfms".freeze

DOWNLOAD_DIR = WorkflowPaths::DOWNLOAD_DIR
DOWNLOAD_BACKUP_DIR = WorkflowPaths::DOWNLOAD_BACKUP_DIR
FileUtils.mkdir_p(DOWNLOAD_DIR)

# -------------------------------------------------------------------------- }}}
# {{{ Get external file using http.

def http_get(uri, cookies = nil)
  http = Net::HTTP.new(uri.host, uri.port)

  req = Net::HTTP::Get.new(uri)
  req['Cookie'] = cookies if cookies

  res = http.request(req)

  [ res, res['set-cookie'] ]
end

# -------------------------------------------------------------------------- }}}
# {{{ Build URI from configured URL string.

def uri_from_url(raw_url)
  URI.parse(raw_url)
rescue URI::InvalidURIError
  URI.parse(URI::DEFAULT_PARSER.escape(raw_url))
end

# -------------------------------------------------------------------------- }}}
# {{{ Backup existing downloaded files.

def next_backup_path(target)
  FileUtils.mkdir_p(DOWNLOAD_BACKUP_DIR)

  date = Time.now.strftime('%Y-%m-%d')
  basename = File.basename(target)
  pattern = /\A#{Regexp.escape(date)}-(\d{3})-#{Regexp.escape(basename)}\z/
  next_number = Dir.children(DOWNLOAD_BACKUP_DIR).filter_map do |entry|
    match = entry.match(pattern)
    match && match[1].to_i
  end.max.to_i + 1

  File.join(DOWNLOAD_BACKUP_DIR, format('%<date>s-%<number>03d-%<basename>s',
                                        date: date,
                                        number: next_number,
                                        basename: basename))
end

def backup_existing_download(name, target)
  return unless File.exist?(target)

  backup = next_backup_path(target)
  FileUtils.cp(target, backup)
  puts "[BACKUP] #{name}: #{target} -> #{backup}"
end

# -------------------------------------------------------------------------- }}}
# {{{ Validate locally staged file strategies.

def validate_local_source?(name, target, location, local, label)
  if File.exist?(target)
    backup_existing_download(name, target)
    puts "[#{label}] #{name}: #{target}"
    return true
  end

  if location && location.to_s != local.to_s
    source_path = File.expand_path(location.to_s, DOWNLOAD_DIR)
    if File.exist?(source_path)
      backup_existing_download(name, target)
      FileUtils.cp(source_path, target)
      puts "[#{label}] #{name}: #{source_path} -> #{target}"
      return true
    end

    puts "[FAIL] #{name}: #{label.downcase} source required (missing #{target} or #{source_path})"
    return false
  end

  puts "[FAIL] #{name}: #{label.downcase} source required (missing #{target})"
  false
end

# -------------------------------------------------------------------------- }}}
# {{{ Resolve script strategy configuration.

def script_config(src)
  raw = src[:script] || src[:command]

  case raw
  when Hash
    path = raw[:path] || raw[:file]
    args = raw[:args] || []
  else
    path = raw
    args = src[:args] || src[:script_args] || []
  end

  [ path.to_s.strip, Array(args).map(&:to_s) ]
end

# -------------------------------------------------------------------------- }}}
# {{{ Run a configured Ruby source script.

def run_source_script?(name, target, src)
  script_path, args = script_config(src)

  if script_path.empty?
    puts "[FAIL] #{name}: strategy :script requires source.script.path"
    return false
  end

  root = ROOT
  full_path = File.expand_path(script_path, root)
  unless full_path == root || full_path.start_with?("#{root}#{File::SEPARATOR}")
    puts "[FAIL] #{name}: script must be inside #{root}"
    return false
  end

  unless File.file?(full_path)
    puts "[FAIL] #{name}: script missing #{full_path}"
    return false
  end

  puts "[SCRIPT] #{name}: ruby #{script_path} #{args.join(' ')}"
  backup_existing_download(name, target)
  success = system(RbConfig.ruby, full_path, *args)
  unless success
    puts "[FAIL] #{name}: script failed #{script_path}"
    return false
  end

  unless File.exist?(target)
    puts "[FAIL] #{name}: script completed but did not create #{target}"
    return false
  end

  puts "[OK] #{name}: #{script_path} -> #{target}"
  true
end

# -------------------------------------------------------------------------- }}}
# {{{ Establish session + capture cookies (only needed if any :http files are extracted)

selected_entries = EtlHelpers.selected_dsl_entries(DSL_MAP, ARGV)

needs_http = selected_entries.any? do |_name, cfg|
  next false unless Workflow.wants_step?(cfg, :download)

  EtlHelpers.source_strategy(cfg) == :http
end

cookies = nil
if needs_http
  vcfms_uri = URI(VCFMS_URL)
  res, cookies = http_get(vcfms_uri)
  abort 'Failed to establish session cookies' unless cookies
end

# -------------------------------------------------------------------------- }}}
# {{{ Main logic

puts 'Download started.'

stats = EtlHelpers::RunStats.new

selected_entries.each do |name, cfg|
  unless Workflow.wants_step?(cfg, :download)
    puts "[SKIP] #{name}: step disabled (:download)"
    stats.skip!
    next
  end

  src = EtlHelpers.source(cfg)
  strategy = EtlHelpers.source_strategy(cfg)
  local = EtlHelpers.source_local(cfg)
  location = EtlHelpers.source_location(cfg)
  url = src[:url]

  if local.nil? || local.to_s.strip.empty?
    puts "[FAIL] #{name}: missing source.local"
    stats.fail!
    next
  end

  target = File.join(DOWNLOAD_DIR, local)

  case strategy
  when :manual
    validate_local_source?(name, target, location, local, 'MANUAL') ? stats.ok! : stats.fail!

  when :append
    validate_local_source?(name, target, location, local, 'APPEND') ? stats.ok! : stats.fail!

  when :copy
    location_s = location.to_s.strip
    if location_s.empty?
      puts "[FAIL] #{name}: strategy :copy requires source.location"
      stats.fail!
      next
    end

    source_path = File.expand_path(location_s, DOWNLOAD_DIR)
    unless File.exist?(source_path)
      puts "[FAIL] #{name}: copy source missing #{source_path}"
      stats.fail!
      next
    end

    begin
      backup_existing_download(name, target)
      FileUtils.cp(source_path, target)
      puts "[OK] #{name}: #{source_path} -> #{target}"
      stats.ok!
    rescue StandardError => e
      puts "[FAIL] #{name}: #{source_path}: #{e}"
      stats.fail!
    end

  when :script
    run_source_script?(name, target, src) ? stats.ok! : stats.fail!

  when :http
    url_s = (url || '').to_s.strip
    if url_s.empty?
      puts "[FAIL] #{name}: strategy :http requires source.url"
      stats.fail!
      next
    end

    begin
      uri = uri_from_url(url_s)
      res, = http_get(uri, cookies)

      unless res.is_a?(Net::HTTPSuccess)
        puts "[FAIL] #{name}: #{url_s}: HTTP #{res.code}"
        stats.fail!
        next
      end

      backup_existing_download(name, target)
      File.binwrite(target, res.body)
      puts "[OK] #{name}: #{url_s} -> #{target}\n"
      stats.ok!
    rescue StandardError => e
      puts "[FAIL] #{name}: #{url_s}: #{e}"
      stats.fail!
    end

  else
    puts "[FAIL] #{name}: unknown strategy #{strategy.inspect}"
    stats.fail!
  end
end

# -------------------------------------------------------------------------- }}}
# {{{ Execution summary

puts "\n#{stats.summary}"
puts 'Download completed.'

# -------------------------------------------------------------------------- }}}
