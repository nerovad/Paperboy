# frozen_string_literal: true

require 'yaml'

module Paperboy
  module Gitea
    class IssueTemplate
      # Turns one markdown issue template into a type and its fields.
      class Loader
        def self.load(dir = TEMPLATE_DIR)
          names = Dir.children(dir).grep(/\.md\z/).sort
          names.map { |name| new(File.join(dir, name)).load }
               .sort_by { |type| sort_key(type.key) }
        end

        def self.sort_key(key)
          index = TYPE_ORDER.index(key)
          [index.nil? ? 1 : 0, index || key]
        end

        def initialize(path)
          @path = path
        end

        def load
          meta, body = split(File.read(@path, encoding: 'UTF-8'))
          labels = label_names(meta['labels'])
          raise Invalid, "Issue template has no label: #{@path}" if labels.empty?

          Type.new(
            key: type_key(labels),
            name: required_meta(meta, 'name'),
            about: required_meta(meta, 'about'),
            label: type_key(labels),
            fields: fields_for(body),
            source_body: body
          )
        end

        private

        def split(text)
          text = text.sub(/\A\uFEFF/, '').gsub("\r\n", "\n")
          return [{}, text] unless text.start_with?("---\n")

          _empty, yaml, body = text.split(/^---\s*\n/, 3)
          [YAML.safe_load(yaml) || {}, body.to_s.sub(/\A\n/, '')]
        rescue Psych::SyntaxError => e
          raise Invalid, "Issue template front matter is invalid: #{e.message}"
        end

        def required_meta(meta, key)
          value = meta[key].to_s.strip
          raise Invalid, "Issue template is missing #{key}: #{@path}" if value.empty?

          value
        end

        def label_names(value)
          case value
          when Array then value.map { |label| label.to_s.strip }.reject(&:empty?)
          when String then value.split(',').map(&:strip).reject(&:empty?)
          else []
          end
        end

        def type_key(labels)
          labels.find { |label| TYPE_ORDER.include?(label) } || labels.first
        end

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

      # Classifies one template section as prose, steps, prompts, or checks.
      class FieldBuilder
        def self.build(heading, section)
          new(heading, section).build
        end

        def initialize(heading, section)
          @heading = heading
          @lines = section.lines.map(&:strip).reject(&:empty?)
          @section = section
        end

        def build
          kind, extra = classify
          optional = @heading == 'Additional context'
          Field.new(
            id: ident(@heading), heading: @heading, kind: kind, optional: optional,
            content_required: !optional && %w[text steps checklist].include?(kind),
            help: kind == 'text' ? @section : nil, hint: hint_for(kind),
            options: extra[:options] || [], prompts: extra[:prompts] || []
          )
        end

        private

        def classify
          return ['checks', { options: checkbox_labels }] if labeled_checks?
          return ['checklist', {}] if @lines.any? && @lines.all? { |line| line.match?(/\A- \[[ xX]\]/) }
          return ['prompts', { prompts: prompt_fields }] if prompt_lines?
          return ['steps', {}] if @lines.any? && @lines.all? { |line| line.match?(/\A\d+[.)]\s*\z/) }

          ['text', {}]
        end

        def labeled_checks?
          @lines.any? && @lines.all? { |line| line.match?(/\A- \[[ xX]\]\s+\S/) }
        end

        def checkbox_labels
          @lines.map { |line| line.sub(/\A- \[[ xX]\]\s+/, '') }
        end

        def prompt_lines?
          @lines.any? && @lines.all? { |line| line.match?(/\A- .+:\s*\z/) }
        end

        def prompt_fields
          @lines.map do |line|
            label = line.sub(/\A- /, '').sub(/:\s*\z/, '')
            Prompt.new(id: ident(label), label: label)
          end
        end

        def hint_for(kind)
          case kind
          when 'text' then @section
          when 'steps' then 'One step per line.'
          when 'checklist' then 'One criterion per line.'
          when 'checks' then 'Select any that apply.'
          end
        end

        def ident(text)
          text.downcase.gsub(/[^a-z0-9]+/, '_').gsub(/\A_+|_+\z/, '')
        end
      end
    end
  end
end
