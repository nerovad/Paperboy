# frozen_string_literal: true

require 'yaml'

module Paperboy
  # Allowlist of repository Markdown files published to the Gitea wiki.
  class WikiCatalog
    class Refused < StandardError; end

    SOURCE_MARKER = /<!-- paperboy-wiki-source: (\S+) -->/
    Page = Struct.new(:source, :slug, :section, :keep, :strip_front_matter, keyword_init: true)

    SLUG = /\A[A-Za-z0-9]+(?:-[A-Za-z0-9]+)*\z/
    SOURCE_PATH = %r{\A(?:[A-Za-z0-9_.-]+/)*[A-Za-z0-9_.-]+\.md\z}

    attr_reader :sections, :pages

    def self.load(path)
      from_hash(YAML.safe_load_file(path))
    end

    def self.from_hash(data)
      data ||= {}
      sections = Array(data['sections']).map(&:to_s)
      pages = Array(data['pages']).map { |row| build_page(row, sections) }
      new(sections, pages)
    end

    def self.build_page(row, sections)
      row ||= {}
      source = row['source'].to_s
      slug = row['slug'].to_s
      section = row['section'].to_s
      validate!(source, slug, section, sections)
      Page.new(source: source, slug: slug, section: section,
               keep: row['keep'] == true, strip_front_matter: row['strip_front_matter'] == true)
    end

    def self.validate!(source, slug, section, sections)
      raise Refused, 'README.md is not published' if source == 'README.md'
      raise Refused, "source is not a repository markdown path: #{source}" if source.include?('..') || !source.match?(SOURCE_PATH)
      raise Refused, "slug is not a wiki filename: #{slug}" unless slug.match?(SLUG)
      raise Refused, "unknown section #{section} for #{source}" unless sections.include?(section)
    end

    def initialize(sections, pages)
      sources = pages.map(&:source)
      slugs = pages.map(&:slug)
      raise Refused, 'duplicate wiki source' if sources.uniq.length != sources.length
      raise Refused, 'duplicate wiki slug' if slugs.uniq.length != slugs.length

      @sections = sections
      @pages = pages
      @by_source = pages.to_h { |page| [page.source, page.slug] }
    end

    def include_source?(source)
      @by_source.key?(source)
    end

    def slug_for(source)
      @by_source[source]
    end

    def paths_longest_first
      @paths_longest_first ||= @by_source.keys.sort_by { |path| -path.length }
    end
  end
end
