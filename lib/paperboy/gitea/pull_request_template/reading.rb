# frozen_string_literal: true

require_relative '../issue_template'

module Paperboy
  module Gitea
    class PullRequestTemplate
      # Small readers shared by the renderer and the body check.
      module Reading
        def text_blank?(field, value)
          text = value.to_s.strip
          text.empty? || squash(text) == squash(field.help)
        end

        def issue_number(value)
          text = value.to_s.strip
          return text if text.match?(/\A\d+\z/)
          return Regexp.last_match(1) if text.match(/\ACloses #(\d+)\z/)

          ''
        end

        def verification_checks(value)
          list = value.is_a?(Hash) ? value['checks'] : []
          Array(list).map { |item| item.to_s.strip }
        end

        def verification_log(value)
          value.is_a?(Hash) ? value['checks_run'].to_s : ''
        end

        def checkbox_labels(section)
          section.to_s.lines.filter_map { |line| line.strip[/^- \[[ xX]\]\s+(.+)$/, 1] }
        end

        def fenced_log(section)
          match = section.to_s.match(/```[^\n]*\n(.*?)```/m)
          match ? match[1].strip : ''
        end

        def section_map(markdown)
          IssueTemplate::Sections.section_map(markdown)
        end

        def squash(text)
          IssueTemplate::Sections.squash(text)
        end

        def newline(text)
          text.end_with?("\n") ? text : "#{text}\n"
        end
      end
    end
  end
end
