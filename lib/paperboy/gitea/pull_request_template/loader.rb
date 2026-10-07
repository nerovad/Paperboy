# frozen_string_literal: true

module Paperboy
  module Gitea
    class PullRequestTemplate
      # Turns the markdown pull request template into fields.
      class Loader
        def self.load(path = PATH)
          new(path).load
        end

        def initialize(path)
          @path = path
        end

        def load
          body = File.read(@path, encoding: 'UTF-8').sub(/\A\uFEFF/, '').gsub("\r\n", "\n")
          body = "#{body.sub(/\n\z/, '')}\n"
          Template.new(fields: fields_for(body), source_body: body)
        end

        private

        def fields_for(body)
          sections(body).map { |heading, section| FieldBuilder.build(heading, section) }
        end

        def sections(body)
          body.split(/^## /).filter_map do |chunk|
            next if chunk.strip.empty?

            heading, rest = chunk.split("\n", 2)
            [heading.to_s.strip, rest.to_s.strip]
          end
        end
      end

      # One section becomes a text area, an issue number, or the verification list.
      class FieldBuilder
        def self.build(heading, section)
          new(heading, section).build
        end

        def initialize(heading, section)
          @heading = heading
          @section = section
        end

        def build
          return issue_field if @heading == 'Issue'
          return verification_field if @heading == 'Verification'

          text_field
        end

        private

        def issue_field
          field('issue', content_required: true, help: 'Closes #', hint: 'Issue number this pull request closes.')
        end

        def verification_field
          checks, log = split_verification
          field('verification', content_required: true, help: log,
                                hint: 'Select any that apply.', options: checks, log_label: 'Checks run')
        end

        def text_field
          optional = @heading == 'Follow-up work'
          field('text', content_required: !optional, optional: optional, help: @section, hint: @section)
        end

        def field(kind, content_required:, help:, hint:, optional: false, options: [], log_label: nil)
          Field.new(id: ident(@heading), heading: @heading, kind: kind, content_required: content_required,
                    optional: optional, help: help, hint: hint, options: options, log_label: log_label)
        end

        def split_verification
          checks = @section.lines.filter_map { |line| line.strip[/^- \[[ xX]\]\s+(.+)$/, 1] }
          fenced = @section.match(/```[^\n]*\n(.*?)```/m)
          raise Invalid, 'Pull request template has no checks-run block.' if fenced.nil? || checks.empty?

          [checks, fenced[1].strip]
        end

        def ident(heading)
          heading.downcase.gsub(/[^a-z0-9]+/, '_').gsub(/\A_|_\z/, '')
        end
      end
    end
  end
end
