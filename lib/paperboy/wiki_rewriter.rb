# frozen_string_literal: true

module Paperboy
  # Rewrites repository Markdown links into wiki links, outside code fences.
  class WikiRewriter
    PROSE_FENCES = %w[text markdown md quote].freeze

    def initialize(catalog)
      @catalog = catalog
    end

    def rewrite(text, source)
      @mark = nil
      @prose_fence = false
      text.each_line.map { |line| step(line, source) }.join
    end

    private

    def step(line, source)
      return close_or_body(line, source) if @mark

      opened = opening_fence(line)
      if opened
        @mark = opened[0]
        @prose_fence = prose_info?(opened[1])
        return line
      end

      rewrite_prose(line, source)
    end

    def close_or_body(line, source)
      if closing_fence?(line, @mark)
        @mark = nil
        @prose_fence = false
        return line
      end

      @prose_fence ? rewrite_prose(line, source) : line
    end

    def opening_fence(line)
      match = line.match(/\A {0,3}(`{3,}|~{3,})[ \t]*([^\n]*)$/)
      return unless match

      [match[1], match[2].strip.split.first.to_s]
    end

    def closing_fence?(line, mark)
      line.match?(/\A {0,3}#{Regexp.escape(mark)}[ \t]*$/)
    end

    def prose_info?(info)
      info.empty? || PROSE_FENCES.include?(info.downcase)
    end

    def rewrite_prose(text, source)
      rewrite_bare(rewrite_code(rewrite_links(text, source), source))
    end

    def rewrite_links(text, source)
      text.gsub(/\[([^\]]*)\]\(([^)\s]+)\)/) do
        slug = lookup(source, Regexp.last_match(2))
        slug ? "[#{Regexp.last_match(1)}](#{slug})" : Regexp.last_match(0)
      end
    end

    def rewrite_code(text, source)
      text.gsub(/`([^`\n]+)`/) do
        body = Regexp.last_match(1).strip
        slug = lookup(source, body)
        slug ? "[`#{body}`](#{slug})" : Regexp.last_match(0)
      end
    end

    def rewrite_bare(text)
      @catalog.paths_longest_first.each do |path|
        slug = @catalog.slug_for(path)
        pattern = %r{(?<![A-Za-z0-9_`.(\[/])#{Regexp.escape(path)}(?![A-Za-z0-9_])}
        text = text.gsub(pattern, "[`#{path}`](#{slug})")
      end
      text
    end

    def lookup(source, raw)
      path, anchor = split_target(raw)
      return if path.nil?

      relative = resolve(source, path)
      slug = relative && @catalog.slug_for(relative)
      return if slug.nil?

      anchor ? "#{slug}##{anchor}" : slug
    end

    def split_target(raw)
      return if raw.match?(%r{\A[a-z][a-z0-9+.-]*://}i) || raw.start_with?('mailto:')

      path, anchor = raw.split('#', 2)
      path = path.to_s.sub(/\?.*/, '').sub(%r{\A\./}, '')
      return if path.empty?

      [path, anchor.to_s.empty? ? nil : anchor]
    end

    def resolve(source, path)
      return path if @catalog.include_source?(path)

      relative = File.expand_path(path, "/#{File.dirname(source)}").delete_prefix('/')
      return if relative.start_with?('../') || relative.include?('/../')

      relative if @catalog.include_source?(relative)
    end
  end
end
