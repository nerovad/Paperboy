# frozen_string_literal: true

require 'json'
require 'net/http'
require 'optparse'
require 'time'
require 'uri'

class GiteaApi
  def initialize(base_url:, owner:, repository:, token:)
    @base_url = base_url.chomp('/')
    @owner = owner
    @repository = repository
    @token = token
  end

  def issues
    get('issues', state: 'open', type: 'issues', limit: 100)
  end

  def pull_requests
    get('pulls', state: 'open', limit: 100)
  end

  def milestones
    get('milestones', state: 'all', limit: 100)
  end

  private

  def get(resource, **params)
    path = "/api/v1/repos/#{@owner}/#{@repository}/#{resource}"
    uri = URI("#{@base_url}#{path}")
    uri.query = URI.encode_www_form(params)
    request = Net::HTTP::Get.new(uri)
    request['Authorization'] = "token #{@token}"
    request['Accept'] = 'application/json'

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
  stale_days: 30
}

OptionParser.new do |parser|
  parser.banner = 'Usage: ruby script/gitea_status_report.rb [options]'
  parser.on('--url URL', 'Gitea base URL') { |value| options[:base_url] = value }
  parser.on('--owner NAME', 'Gitea repository owner') { |value| options[:owner] = value }
  parser.on('--repository NAME', 'Gitea repository name') { |value| options[:repository] = value }
  parser.on('--stale-days DAYS', Integer, 'Days before work is stale (default: 30)') do |value|
    options[:stale_days] = value
  end
end.parse!

token = ENV['GITEA_TOKEN'] || dotenv_value('GITEA_TOKEN')
abort 'GITEA_TOKEN is required; set it in the environment or .env' if token.to_s.empty?

api = GiteaApi.new(
  base_url: options[:base_url],
  owner: options[:owner],
  repository: options[:repository],
  token: token
)
issues = api.issues
pull_requests = api.pull_requests
milestones = api.milestones
stale_before = Time.now - (options[:stale_days] * 86_400)

def issue_reference(item)
  ["##{item.fetch('number')}", item.fetch('title')].join(': ')
end

def updated_at(item)
  Time.parse(item.fetch('updated_at'))
end

def labels_for(item)
  item.fetch('labels', []).map { |label| label.fetch('name') }
end

def linked_issue?(pull_request)
  text = [pull_request['title'], pull_request['body']].compact.join(' ')
  text.match?(/(?:#|issues?\s+)(\d+)/i)
end

def print_items(title, items)
  puts "\n#{title}: #{items.length}"
  items.each { |item| puts "- #{yield(item)}" }
  puts '- none' if items.empty?
end

puts 'Paperboy Gitea status report'
puts "Generated: #{Time.now.iso8601}"
puts "Repository: #{options[:owner]}/#{options[:repository]}"
puts "Stale threshold: #{options[:stale_days]} days"
puts "\nOpen issues: #{issues.length}"
puts "Open pull requests: #{pull_requests.length}"

missing_labels = issues.select { |issue| labels_for(issue).empty? }
missing_milestones = issues.select { |issue| issue['milestone'].nil? }
blocked = issues.select { |issue| labels_for(issue).include?('blocked') }
stale_issues = issues.select { |issue| updated_at(issue) < stale_before }
stale_pull_requests = pull_requests.select { |pull_request| updated_at(pull_request) < stale_before }
unlinked_pull_requests = pull_requests.reject { |pull_request| linked_issue?(pull_request) }

print_items('Issues needing labels', missing_labels) { |issue| issue_reference(issue) }
print_items('Issues needing milestones', missing_milestones) { |issue| issue_reference(issue) }
print_items('Blocked issues', blocked) { |issue| issue_reference(issue) }
print_items('Stale issues', stale_issues) { |issue| issue_reference(issue) }
print_items('Stale pull requests', stale_pull_requests) { |pull_request| issue_reference(pull_request) }
print_items('Pull requests without a linked issue', unlinked_pull_requests) do |pull_request|
  issue_reference(pull_request)
end

puts "\nOpen pull requests needing attention: #{pull_requests.length}"
pull_requests.each { |pull_request| puts "- #{issue_reference(pull_request)}" }
puts '- none' if pull_requests.empty?

puts "\nMilestones"
if milestones.empty?
  puts '- none'
else
  milestones.each do |milestone|
    total = milestone.fetch('open_issues', 0) + milestone.fetch('closed_issues', 0)
    completion = total.zero? ? 0 : (milestone.fetch('closed_issues', 0) * 100 / total)
    puts "- #{milestone.fetch('title')}: #{completion}% complete " \
         "(#{milestone.fetch('open_issues', 0)} open, #{milestone.fetch('closed_issues', 0)} closed)"
  end
end

puts "\nRead-only report: no Gitea state was changed."
