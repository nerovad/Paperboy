# frozen_string_literal: true

require 'json'
require 'net/http'
require 'optparse'
require 'uri'

class GiteaApi
  def initialize(base_url:, owner:, repository:, token:)
    @base_url = base_url.chomp('/')
    @owner = owner
    @repository = repository
    @token = token
  end

  def issue(number)
    request(:get, "/issues/#{number}")
  end

  def labels
    request(:get, '/labels', limit: 100)
  end

  def milestones
    request(:get, '/milestones', state: 'all', limit: 100)
  end

  def add_labels(number, label_ids)
    request(:post, "/issues/#{number}/labels", labels: label_ids)
  end

  def assign_milestone(number, milestone_id)
    request(:patch, "/issues/#{number}", milestone: milestone_id)
  end

  private

  def request(method, resource, body = nil, **params)
    path = "/api/v1/repos/#{@owner}/#{@repository}#{resource}"
    uri = URI("#{@base_url}#{path}")
    uri.query = URI.encode_www_form(params) unless params.empty?
    request_class = { get: Net::HTTP::Get, post: Net::HTTP::Post, patch: Net::HTTP::Patch }.fetch(method)
    request = request_class.new(uri)
    request['Authorization'] = "token #{@token}"
    request['Accept'] = 'application/json'
    if body
      request['Content-Type'] = 'application/json'
      request.body = JSON.generate(body)
    end

    response = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == 'https') do |http|
      http.request(request)
    end
    raise "Gitea API #{response.code}: #{response.body}" unless response.is_a?(Net::HTTPSuccess)

    JSON.parse(response.body)
  end
end

def dotenv_value(name)
  path = ENV.fetch('GITEA_ENV_FILE', '.env')
  return unless File.file?(path)

  line = File.foreach(path).find { |candidate| candidate.match?(/\A#{Regexp.escape(name)}=/) }
  return unless line

  value = line.split('=', 2).last.strip
  value = value[1..-2] if value.length >= 2 && value.start_with?('"', "'")
  value
end

options = {
  base_url: ENV.fetch('GITEA_URL', dotenv_value('GITEA_URL') || 'http://10.135.204.125:3000'),
  owner: ENV.fetch('GITEA_OWNER', dotenv_value('GITEA_OWNER') || 'BSS'),
  repository: ENV.fetch('GITEA_REPOSITORY', dotenv_value('GITEA_REPOSITORY') || 'Paperboy'),
  labels: [],
  apply: false
}

OptionParser.new do |parser|
  parser.banner = 'Usage: ruby script/gitea_apply_updates.rb --issue NUMBER [options]'
  parser.on('--issue NUMBER', Integer, 'Issue number to update') { |value| options[:issue] = value }
  parser.on('--add-label NAME', 'Add a repository label (repeatable)') { |value| options[:labels] << value }
  parser.on('--milestone TITLE', 'Assign the named milestone') { |value| options[:milestone] = value }
  parser.on('--apply', 'Apply the planned remote changes') { options[:apply] = true }
  parser.on('--url URL', 'Gitea base URL') { |value| options[:base_url] = value }
  parser.on('--owner NAME', 'Gitea repository owner') { |value| options[:owner] = value }
  parser.on('--repository NAME', 'Gitea repository name') { |value| options[:repository] = value }
end.parse!

abort '--issue is required' unless options[:issue]
abort 'At least one update is required' if options[:labels].empty? && options[:milestone].nil?

token = ENV['GITEA_TOKEN'] || dotenv_value('GITEA_TOKEN')
abort 'GITEA_TOKEN is required; set it in the environment or .env' if token.to_s.empty?

api = GiteaApi.new(
  base_url: options[:base_url],
  owner: options[:owner],
  repository: options[:repository],
  token: token
)
issue = api.issue(options[:issue])
available_labels = api.labels
available_milestones = api.milestones
current_labels = issue.fetch('labels', []).map { |label| label.fetch('name') }

selected_labels = options[:labels].map do |name|
  available_labels.find { |label| label.fetch('name') == name } || abort("Unknown label: #{name}")
end
new_labels = selected_labels.reject { |label| current_labels.include?(label.fetch('name')) }

selected_milestone = if options[:milestone]
                       available_milestones.find { |milestone| milestone.fetch('title') == options[:milestone] } ||
                         abort("Unknown milestone: #{options[:milestone]}")
                     end
milestone_change = selected_milestone && issue.dig('milestone', 'id') != selected_milestone.fetch('id')

puts 'Gitea update plan'
puts "Issue: ##{options[:issue]} — #{issue.fetch('title')}"
new_labels.each { |label| puts "- add label: #{label.fetch('name')}" }
puts "- assign milestone: #{selected_milestone.fetch('title')}" if milestone_change
puts '- no changes required' if new_labels.empty? && !milestone_change

unless options[:apply]
  puts 'Dry run only: no Gitea state was changed. Use --apply to execute this plan.'
  exit
end

unless new_labels.empty?
  api.add_labels(options[:issue], new_labels.map { |label| label.fetch('id') })
  puts "Applied labels: #{new_labels.map { |label| label.fetch('name') }.join(', ')}"
end

if milestone_change
  api.assign_milestone(options[:issue], selected_milestone.fetch('id'))
  puts "Applied milestone: #{selected_milestone.fetch('title')}"
end

puts "Audit: issue ##{options[:issue]} updated by explicit --apply request."
