# frozen_string_literal: true

module Paperboy
  module Gitea
    # The pull request template in git is the only definition of a pull
    # request body. The Development form and bin/create-pull-request both
    # ask this class to render and check that body.
    class PullRequestTemplate
      class Invalid < StandardError; end

      PATH = File.expand_path('../../../.gitea/pull_request_template.md', __dir__).freeze

      Field = Struct.new(
        :id, :heading, :kind, :content_required, :optional, :help, :hint, :options, :log_label,
        keyword_init: true
      )
      Template = Struct.new(:fields, :source_body, keyword_init: true)

      class << self
        def template
          Loader.load
        end

        def fields
          template.fields
        end

        def render(answers)
          Body.render(template, answers)
        end

        def body_errors(markdown)
          Body.errors_for(template, markdown)
        end

        def valid_body?(markdown)
          body_errors(markdown).empty?
        end

        def skeleton
          template.source_body
        end

        def summary
          Body.summary(template)
        end

        def close_issue(markdown, number)
          Body.close_issue(markdown, number)
        end
      end
    end
  end
end

require_relative 'pull_request_template/loader'
require_relative 'pull_request_template/body'
require_relative 'pull_request_template/cli'

Paperboy::Gitea::PullRequestTemplate::Cli.call(ARGV) if $PROGRAM_NAME == __FILE__
