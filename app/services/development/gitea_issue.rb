# frozen_string_literal: true

require 'json'
require 'open3'
require 'timeout'

module Development
  # Reads one issue so the update form can show its title, template body,
  # labels, milestone, project, and column. A failed lookup leaves the form
  # blank. This is not a workflow run.
  class GiteaIssue
    def self.fetch(number)
      stdout, _stderr, status = Timeout.timeout(20) do
        Open3.capture3(
          { 'GITEA_CONNECT_TIMEOUT' => '3', 'GITEA_MAX_TIME' => '5' },
          Rails.root.join('bin/gitea-issue').to_s,
          number.to_s
        )
      end
      return unless status.success?

      parsed = JSON.parse(stdout)
      parsed if parsed.is_a?(Hash)
    rescue StandardError
      nil
    end

    def self.for_form(number)
      payload = fetch(number)
      return if payload.nil?

      result = placement(payload).merge(
        number: payload['number'], title: payload['title'].to_s, type: nil, answers: {}, body_error: nil
      )
      type = Paperboy::Gitea::IssueTemplate.type_for_labels(payload['labels'])
      return result.merge(body_error: missing_type_message) if type.nil?

      answers = Paperboy::Gitea::IssueTemplate.answers_for(type, payload['body'].to_s)
      result.merge(type: type, answers: { type => answers })
    rescue Paperboy::Gitea::IssueTemplate::Invalid => e
      result.merge(body_error: e.message)
    end

    def self.placement(payload)
      projects = Array(payload['projects']).map { |item| item.to_s.strip }.reject(&:empty?)
      {
        labels: Array(payload['labels']).map { |item| item.to_s.strip }.reject(&:empty?),
        milestone: text_or_nil(payload['milestone']),
        projects: projects,
        project: projects.one? ? projects.first : nil,
        column: text_or_nil(payload['column'])
      }
    end

    def self.text_or_nil(value)
      text = value.to_s.strip
      text.empty? ? nil : text
    end

    def self.missing_type_message
      'This issue has no bug, feature, chore, or infrastructure label.'
    end
    private_class_method :placement, :text_or_nil, :missing_type_message
  end
end
