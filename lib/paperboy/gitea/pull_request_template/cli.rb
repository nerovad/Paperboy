# frozen_string_literal: true

require 'json'

module Paperboy
  module Gitea
    class PullRequestTemplate
      # The bash script calls this file directly. Rails autoload is not involved.
      class Cli
        def self.call(argv)
          new(argv).call
        rescue PullRequestTemplate::Invalid, JSON::ParserError, Errno::ENOENT => e
          warn e.message
          exit 2
        end

        def initialize(argv)
          @argv = argv
        end

        def call
          case @argv.shift
          when 'summary' then $stdout.write(PullRequestTemplate.summary)
          when 'skeleton' then $stdout.write(PullRequestTemplate.skeleton)
          when 'render' then $stdout.write(PullRequestTemplate.render(answers))
          when 'validate-body' then validate_body
          when 'close-issue' then $stdout.write(PullRequestTemplate.close_issue(body, flag(:issue, '--issue')))
          else raise Invalid, 'Unknown pull request template command'
          end
        end

        private

        def answers
          JSON.parse(File.read(flag(:answers, '--answers-file')))
        end

        def validate_body
          errors = PullRequestTemplate.body_errors(body)
          raise Invalid, errors.join("\n") if errors.any?
        end

        def body
          File.read(flag(:body, '--body-file'))
        end

        def flag(name, option)
          value = flags[name].to_s
          raise Invalid, "#{option} is required" if value.empty?

          value
        end

        def flags
          @flags ||= parse_flags
        end

        def parse_flags
          parsed = {}
          args = @argv.dup
          while (arg = args.shift)
            case arg
            when '--answers-file' then parsed[:answers] = args.shift
            when '--body-file' then parsed[:body] = args.shift
            when '--issue' then parsed[:issue] = args.shift
            else raise Invalid, "Unknown option: #{arg}"
            end
          end
          parsed
        end
      end
    end
  end
end
