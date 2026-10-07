# frozen_string_literal: true

require 'json'

module Paperboy
  module Gitea
    class IssueTemplate
      # The bash scripts call this file directly. Rails autoload is not involved.
      class Cli
        def self.call(argv)
          new(argv).call
        rescue IssueTemplate::Invalid, JSON::ParserError, Errno::ENOENT => e
          warn e.message
          exit 2
        end

        def initialize(argv)
          @argv = argv
        end

        def call
          command = @argv.shift
          case command
          when 'keys' then puts IssueTemplate.keys
          when 'label' then puts IssueTemplate.label_for(type)
          when 'summary' then $stdout.write(IssueTemplate.summary(type))
          when 'skeleton' then $stdout.write(IssueTemplate.skeleton(type))
          when 'render' then $stdout.write(IssueTemplate.render(type, answers))
          when 'validate-body' then validate_body
          else raise Invalid, 'Unknown issue template command'
          end
        end

        private

        def type
          value = flags[:type].to_s
          raise Invalid, 'Type is required' if value.empty?

          value
        end

        def answers
          JSON.parse(File.read(flag(:answers, '--answers-file')))
        end

        def validate_body
          errors = IssueTemplate.body_errors(type, File.read(flag(:body, '--body-file')))
          raise Invalid, errors.join("\n") if errors.any?
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
            when '--type' then parsed[:type] = args.shift
            when '--answers-file' then parsed[:answers] = args.shift
            when '--body-file' then parsed[:body] = args.shift
            else raise Invalid, "Unknown option: #{arg}"
            end
          end
          parsed
        end
      end
    end
  end
end
