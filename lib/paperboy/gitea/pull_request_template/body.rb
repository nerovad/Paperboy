# frozen_string_literal: true

require_relative 'reading'
require_relative 'review'

module Paperboy
  module Gitea
    class PullRequestTemplate
      # Renders answers into the template's markdown.
      class Body
        include Reading

        def self.render(template, answers)
          new(template, normalize(answers)).render
        end

        def self.errors_for(template, markdown)
          Review.errors_for(template, markdown)
        end

        def self.close_issue(markdown, number)
          Review.close_issue(markdown, number)
        end

        def self.summary(template)
          lines = ['Pull request', '']
          template.fields.each { |field| lines.concat(field_summary(field)) }
          "#{lines.join("\n")}\n"
        end

        def self.field_summary(field)
          state = field.content_required ? 'required' : 'optional'
          lines = ["- #{field.id}: #{field.heading} (#{state})"]
          return lines unless field.kind == 'verification'

          lines << '  - checks'
          field.options.each { |option| lines << "    - #{option}" }
          lines << '  - checks_run (required)'
        end

        def self.normalize(value)
          if value.respond_to?(:to_unsafe_h)
            normalize(value.to_unsafe_h)
          elsif value.is_a?(Hash)
            value.each_with_object({}) { |(key, item), result| result[key.to_s] = normalize(item) }
          elsif value.is_a?(Array)
            value.map { |item| normalize(item) }
          else
            value.nil? ? '' : value.to_s
          end
        end

        def initialize(template, answers)
          @template = template
          @answers = answers
        end

        def render
          missing = answer_errors
          raise Invalid, missing.join(' ') if missing.any?

          parts = @template.fields.filter_map { |field| render_field(field, @answers[field.id]) }
          rendered = "#{parts.join("\n\n")}\n"
          leftover = errors_for(rendered)
          raise Invalid, leftover.join(' ') if leftover.any?

          rendered
        end

        private

        def errors_for(markdown)
          self.class.errors_for(@template, markdown)
        end

        def answer_errors
          @template.fields.filter_map do |field|
            next unless field.content_required
            next unless blank_answer?(field, @answers[field.id])

            "#{label_for(field)} is required."
          end
        end

        def render_field(field, value)
          case field.kind
          when 'issue' then "## #{field.heading}\n\nCloses ##{issue_number(value)}"
          when 'verification' then render_verification(field, value)
          else render_text(field, value)
          end
        end

        def render_text(field, value)
          text = value.to_s.strip
          return if field.optional && text_blank?(field, text)

          "## #{field.heading}\n\n#{text}"
        end

        def render_verification(field, value)
          selected = verification_checks(value)
          boxes = field.options.map { |option| "- [#{selected.include?(option) ? 'x' : ' '}] #{option}" }
          "## #{field.heading}\n\n#{boxes.join("\n")}\n\n#{field.log_label}:\n\n```text\n#{verification_log(value).strip}\n```"
        end

        def blank_answer?(field, value)
          case field.kind
          when 'issue' then issue_number(value).empty?
          when 'verification' then verification_log(value).strip.empty? || text_blank?(field, verification_log(value))
          else text_blank?(field, value)
          end
        end

        def label_for(field)
          field.kind == 'verification' ? 'Checks run' : field.heading
        end
      end
    end
  end
end
