# frozen_string_literal: true

require_relative 'sections'
require_relative 'body'

module Paperboy
  module Gitea
    class IssueTemplate
      # Reads a stored issue body back into the answers render accepts.
      class Answers
        def self.for(type, markdown)
          new(type, markdown).to_h
        end

        def initialize(type, markdown)
          @type = type
          @markdown = markdown
        end

        def to_h
          sections = Sections.section_map(@markdown)
          errors = Body.errors_for(@type, @markdown)
          unexpected = sections.keys - @type.fields.map(&:heading)
          errors << "Unexpected section: #{unexpected.join(', ')}." if unexpected.any?
          raise Invalid, errors.join(' ') if errors.any?

          @type.fields.to_h { |field| [field.id, read_field(field, sections[field.heading])] }
        end

        private

        def read_field(field, section)
          return blank_for(field) if section.nil?

          case field.kind
          when 'text' then section.strip
          when 'steps' then Sections.step_texts(section).join("\n")
          when 'checklist' then checklist_value(section)
          when 'prompts' then prompt_values(field, section)
          when 'checks' then selected_checks(field, section)
          end
        end

        # A plain criterion is boxed on the way out. A box that is already
        # checked has to stay checked, or loading the issue would clear it.
        def checklist_value(section)
          section.lines.map(&:strip).reject(&:empty?).join("\n")
        end

        def blank_for(field)
          case field.kind
          when 'prompts' then {}
          when 'checks' then []
          else ''
          end
        end

        def prompt_values(field, section)
          lines = content_lines(section)
          known = field.prompts.map { |prompt| "- #{prompt.label}:" }
          refuse_unknown(field, lines.reject { |line| known.any? { |prefix| line.start_with?(prefix) } })
          field.prompts.each_with_object({}) do |prompt, values|
            line = lines.find { |item| item.start_with?("- #{prompt.label}:") }
            values[prompt.id] = line.to_s.delete_prefix("- #{prompt.label}:").strip
          end
        end

        def selected_checks(field, section)
          lines = content_lines(section)
          known = field.options.map { |option| /\A- \[[ xX]\] #{Regexp.escape(option)}\z/ }
          refuse_unknown(field, lines.reject { |line| known.any? { |pattern| line.match?(pattern) } })
          field.options.select do |option|
            lines.any? { |line| line.match?(/\A- \[[xX]\] #{Regexp.escape(option)}\z/) }
          end
        end

        def content_lines(section)
          section.lines.map(&:strip).reject(&:empty?)
        end

        def refuse_unknown(field, lines)
          return if lines.empty?

          raise Invalid, "Unexpected line in #{field.heading}: #{lines.first}."
        end
      end
    end
  end
end
