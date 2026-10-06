# frozen_string_literal: true

require 'fileutils'

module Paperboy
  # Renders catalog pages, Home, and the sidebar for the Gitea wiki.
  class WikiRenderer
    def initialize(catalog, repo_html_url:)
      @catalog = catalog
      @repo_html_url = repo_html_url.to_s.sub(%r{/\z}, '')
      @rewriter = WikiRewriter.new(catalog)
    end

    def render(root)
      pages = {}
      @catalog.pages.each do |page|
        body = read_page(root, page)
        pages["#{page.slug}.md"] = render_page(page, body) unless body.nil?
      end
      pages['Home.md'] = home
      pages['_Sidebar.md'] = sidebar
      pages
    end

    def write(root, dest)
      FileUtils.mkdir_p(dest)
      render(root).each { |name, body| File.write(File.join(dest, name), body, encoding: 'UTF-8') }
    end

    private

    def read_page(root, page)
      path = File.join(root, page.source)
      return File.read(path, encoding: 'UTF-8') if File.file?(path)
      raise WikiCatalog::Refused, "missing kept wiki source: #{page.source}" if page.keep

      nil
    end

    def render_page(page, raw)
      body = raw.sub(/\A\uFEFF/, '').gsub("\r\n", "\n")
      body = strip_front_matter(body) if page.strip_front_matter
      "#{front_matter}#{insert_banner(@rewriter.rewrite(body, page.source), banner_for(page))}"
    end

    def strip_front_matter(text)
      stripped = text.sub(/\A---\r?\n.*?---\r?\n/m, '')
      raise WikiCatalog::Refused, 'wiki template front matter did not close' if stripped.start_with?('---')

      stripped.sub(/\A\r?\n/, '')
    end

    def front_matter
      "---\ninclude_toc: true\ngitea: none\n---\n\n"
    end

    def banner_for(page)
      follow = if page.keep
                 'Edit that file and run `bin/wiki-publish`. This wiki page is replaced on the next publish.'
               else
                 'Edit this page in the wiki.'
               end
      verb = page.keep ? 'Refreshed from' : 'Moved from'
      "> #{verb} `#{page.source}` in the Paperboy repository. #{follow}\n\n" \
        "<!-- paperboy-wiki-source: #{page.source} -->\n"
    end

    def insert_banner(body, banner)
      return "#{banner}\n#{body}" unless body.match?(/\A# /)

      head, rest = body.split("\n", 2)
      "#{head}\n\n#{banner}\n#{rest}"
    end

    def home
      readme = "#{@repo_html_url}/src/branch/master/README.md"
      pdf = "#{@repo_html_url}/src/branch/master/docs/PAPERBOY_TECHNICAL_DOCUMENTATION.pdf"
      "#{front_matter}# Paperboy\n\n" \
        "Setup and the clone landing page stay in the repository [README](#{readme}).\n\n" \
        "The technical PDF stays in the repository: [Paperboy technical documentation](#{pdf}).\n\n" \
        'Pages that moved out of the docs directory are edited here. AGENTS.md, CLAUDE.md, ' \
        'the .gitea templates, and the directory READMEs stay in git and are refreshed by ' \
        "bin/wiki-publish.\n\n" \
        "<!-- paperboy-wiki-source: generated-home -->\n\n" \
        "#{navigation}"
    end

    def sidebar
      "<!-- paperboy-wiki-source: generated-sidebar -->\n\n#{navigation(include_home: true)}"
    end

    def navigation(include_home: false)
      blocks = @catalog.sections.map do |section|
        lines = ["## #{section}", '']
        lines << '- [Home](Home)' if include_home && section == @catalog.sections.first
        @catalog.pages.each do |page|
          lines << "- [#{page.slug.tr('-', ' ')}](#{page.slug})" if page.section == section
        end
        lines.join("\n")
      end
      "#{blocks.join("\n\n")}\n"
    end
  end
end
