# frozen_string_literal: true

require_relative 'sections'

module Paperboy
  module Gitea
    class IssueTemplate
      # Renders answers into the template's markdown and checks a body
      # against the same sections.
      class Body
        def self.render(type, answers)
          new(type, normalize(answers)).render
        end

        def self.errors_for(type, markdown)
          new(type, {}).errors_for(markdown)
        end

        def self.summary(type)
          Sections.summary(type)
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

        def initialize(type, answers)
          @type = type
          @answers = answers
        end

        def render
          missing = answer_errors
          raise Invalid, missing.join(' ') if missing.any?

          parts = @type.fields.filter_map { |field| render_field(field, @answers[field.id]) }
          rendered = "#{parts.join("\n\n")}\n"
          leftover = errors_for(rendered)
          raise Invalid, leftover.join(' ') if leftover.any?

          rendered
        end

        def errors_for(markdown)
          sections = Sections.section_map(markdown)
          @type.fields.filter_map { |field| field_error(field, sections[field.heading]) }
        end

        private

        def answer_errors
          @type.fields.filter_map do |field|
            next unless field.content_required
            next unless blank_value?(field, @answers[field.id])

            "#{field.heading} is required."
          end
        end

        def field_error(field, section)
          return "#{field.heading} is required." if section.nil? && !field.optional
          return unless field.content_required && section && section_blank?(field, section)

          "#{field.heading} is required."
        end

        def render_field(field, value)
          case field.kind
          when 'text' then render_text(field, value)
          when 'steps' then render_lines(field, number_lines(value))
          when 'checklist' then render_lines(field, checklist_lines(value))
          when 'prompts' then render_lines(field, prompt_lines(field, value))
          when 'checks' then render_lines(field, check_lines(field, value))
          end
        end

        def render_text(field, value)
          text = value.to_s.strip
          return nil if text.empty? && field.optional

          "## #{field.heading}\n\n#{text}"
        end

        def render_lines(field, lines)
          "## #{field.heading}\n\n#{lines.join("\n")}"
        end

        def number_lines(value)
          Sections.step_texts(value).each_with_index.map { |line, index| "#{index + 1}. #{line}" }
        end

        def checklist_lines(value)
          value.to_s.lines.map(&:strip).reject(&:empty?).map do |line|
            line.match?(/\A- \[[ xX]\]/) ? line : "- [ ] #{line}"
          end
        end

        def prompt_lines(field, value)
          picked = value.is_a?(Hash) ? value : {}
          field.prompts.map { |prompt| "- #{prompt.label}: #{picked[prompt.id].to_s.strip}" }
        end

        def check_lines(field, value)
          selected = value.is_a?(Array) ? value.map { |item| item.to_s.strip } : []
          field.options.map { |option| "- [#{selected.include?(option) ? 'x' : ' '}] #{option}" }
        end

        def blank_value?(field, value)
          case field.kind
          when 'steps' then Sections.step_texts(value).empty?
          when 'checklist' then Sections.checklist_texts(value).empty?
          else value.to_s.strip.empty? || Sections.squash(value) == Sections.squash(field.help)
          end
        end

        def section_blank?(field, section)
          case field.kind
          when 'steps' then Sections.step_texts(section).empty?
          when 'checklist' then Sections.checklist_texts(section).empty?
          else Sections.squash(section).empty? || Sections.squash(section) == Sections.squash(field.help)
          end
        end
      end
    end
  end
end
