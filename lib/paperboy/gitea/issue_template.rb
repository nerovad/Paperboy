# frozen_string_literal: true

module Paperboy
  module Gitea
    # The issue templates in git are the only definition of an issue body.
    # The Development form and bin/new-issue both ask this class to render
    # and check that body.
    class IssueTemplate
      class Invalid < StandardError; end

      TYPE_ORDER = %w[bug feature chore infrastructure].freeze
      TEMPLATE_DIR = File.expand_path('../../../.gitea/issue_template', __dir__).freeze

      Field = Struct.new(
        :id, :heading, :kind, :content_required, :optional, :help, :hint, :options, :prompts,
        keyword_init: true
      )
      Prompt = Struct.new(:id, :label, keyword_init: true)
      Type = Struct.new(:key, :name, :about, :label, :fields, :source_body, keyword_init: true)

      class << self
        def types
          Loader.load
        end

        def find(key)
          types.find { |type| type.key == key.to_s } ||
            raise(Invalid, "Unsupported issue type: #{key}")
        end

        def render(type_key, answers)
          Body.render(find(type_key), answers)
        end

        def body_errors(type_key, markdown)
          Body.errors_for(find(type_key), markdown)
        end

        def valid_body?(type_key, markdown)
          body_errors(type_key, markdown).empty?
        end

        def label_for(type_key)
          find(type_key).label
        end

        def skeleton(type_key)
          body = find(type_key).source_body
          body.end_with?("\n") ? body : "#{body}\n"
        end

        def summary(type_key)
          Body.summary(find(type_key))
        end

        def answers_for(type_key, markdown)
          Answers.for(find(type_key), markdown)
        end

        def type_for_labels(labels)
          names = Array(labels).map(&:to_s)
          TYPE_ORDER.find { |key| names.include?(key) }
        end

        def keys
          types.map(&:key).join(' ')
        end
      end
    end
  end
end

require_relative 'issue_template/loader'
require_relative 'issue_template/body'
require_relative 'issue_template/answers'
require_relative 'issue_template/cli'

Paperboy::Gitea::IssueTemplate::Cli.call(ARGV) if $PROGRAM_NAME == __FILE__
