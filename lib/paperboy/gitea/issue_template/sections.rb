# frozen_string_literal: true

module Paperboy
  module Gitea
    class IssueTemplate
      # Shared reading of the markdown the templates and submitted bodies use.
      module Sections
        module_function

        def section_map(markdown)
          text = markdown.to_s.sub(/\A\uFEFF/, '').gsub("\r\n", "\n").strip
          text.split(/^## /).filter_map do |chunk|
            next if chunk.strip.empty?

            heading, rest = chunk.split("\n", 2)
            [heading.to_s.strip, rest.to_s.strip]
          end.to_h
        end

        def step_texts(value)
          value.to_s.lines.filter_map do |line|
            text = line.strip.sub(/\A\d+[.)]\s*/, '')
            text unless text.empty?
          end
        end

        def checklist_texts(value)
          value.to_s.lines.filter_map do |line|
            stripped = line.strip
            next if stripped.empty? || stripped.match?(/\A- \[[ xX]\]\s*\z/)

            stripped.sub(/\A- \[[ xX]\]\s+/, '')
          end
        end

        def squash(text)
          text.to_s.gsub(/\s+/, ' ').strip
        end

        def summary(type)
          lines = [type.name, type.about, '']
          type.fields.each { |field| lines.concat(field_summary(field)) }
          "#{lines.join("\n")}\n"
        end

        def field_summary(field)
          state = field.content_required ? 'required' : 'optional'
          lines = ["- #{field.id}: #{field.heading} (#{state})"]
          field.prompts.each { |prompt| lines << "  - #{prompt.id}: #{prompt.label}" }
          field.options.each { |option| lines << "  - #{option}" }
          lines
        end
      end
    end
  end
end
