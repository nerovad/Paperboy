# frozen_string_literal: true

require_relative 'reading'

module Paperboy
  module Gitea
    class PullRequestTemplate
      # Checks a markdown body and fills Closes #N into the Issue section.
      class Review
        include Reading

        def self.errors_for(template, markdown)
          new(template).errors_for(markdown)
        end

        def self.close_issue(markdown, number)
          new(nil).close_issue(markdown, number)
        end

        def initialize(template)
          @template = template
        end

        def errors_for(markdown)
          sections = section_map(markdown)
          @template.fields.filter_map { |field| field_error(field, sections[field.heading]) }
        end

        def close_issue(markdown, number)
          raise Invalid, 'Issue must be a number.' unless number.to_s.match?(/\A\d+\z/)

          sections = section_map(markdown)
          current = sections['Issue']
          raise Invalid, 'Issue is required.' if current.nil?
          return newline(markdown) if current.strip == "Closes ##{number}"

          found = current.strip[/\ACloses #(\d+)\z/, 1]
          raise Invalid, "Issue closes ##{found}, not ##{number}." if found
          raise Invalid, 'Issue must be Closes #<number>.' unless current.strip == 'Closes #'

          sections['Issue'] = "Closes ##{number}"
          newline(sections.map { |heading, body| "## #{heading}\n\n#{body}" }.join("\n\n"))
        end

        private

        def field_error(field, section)
          return if field.optional
          return "#{field.heading} is required." if section.nil?
          return issue_error(section) if field.kind == 'issue'
          return verification_error(field, section) if field.kind == 'verification'
          return unless text_blank?(field, section)

          "#{field.heading} is required."
        end

        def verification_error(field, section)
          missing = field.options.find { |option| !checkbox_labels(section).include?(option) }
          return "Verification is missing #{missing}." if missing
          return 'Checks run is required.' if text_blank?(field, fenced_log(section))

          nil
        end

        def issue_error(section)
          return 'Issue is required.' if section.strip.empty? || section.strip == 'Closes #'
          return if section.strip.match?(/\ACloses #\d+\z/)

          'Issue must be Closes #<number>.'
        end
      end
    end
  end
end
