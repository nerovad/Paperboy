# frozen_string_literal: true

require 'minitest/autorun'
require 'fileutils'
require 'open3'
require 'tmpdir'
require_relative '../../lib/paperboy/wiki_publish'

module WikiPublishFixtures
  module_function

  def catalog(pages, sections: ['Start'])
    Paperboy::WikiCatalog.from_hash('sections' => sections, 'pages' => pages)
  end

  def tracked_markdown(root)
    output, status = Open3.capture2('git', '-C', root, 'ls-files', '*.md')
    raise 'git ls-files failed' unless status.success?

    output.lines.map(&:strip).reject { |path| path == 'README.md' || path.empty? }
  end

  def sample_markdown
    <<~MD
      See [the pitch](docs/PITCH.md) and `docs/aim/aim_plan.md`.
      Also docs/PITCH.md in prose.
      Leave [the site](https://example.com/docs/PITCH.md) alone.

      ```bash
      cat docs/PITCH.md
      ```

      ```text
      Read docs/aim/aim_plan.md before doing anything.
      ```
    MD
  end
end

class WikiPublishTest < Minitest::Test
  ROOT = File.expand_path('../..', __dir__)
  REPO_URL = 'http://gitea.example/BSS/Paperboy'

  def test_catalog_refuses_readme
    error = assert_raises(Paperboy::WikiCatalog::Refused) do
      WikiPublishFixtures.catalog([{ 'source' => 'README.md', 'slug' => 'Readme', 'section' => 'Start' }])
    end

    assert_match 'README.md is not published', error.message
  end

  def test_shipped_catalog_includes_every_tracked_markdown_file_except_readme
    loaded = Paperboy::WikiCatalog.load(File.join(ROOT, 'config/wiki_pages.yml'))
    sources = loaded.pages.map(&:source)

    refute_includes sources, 'README.md'
    WikiPublishFixtures.tracked_markdown(ROOT).each do |path|
      assert_includes sources, path
    end
    loaded.pages.select(&:keep).each do |page|
      assert File.file?(File.join(ROOT, page.source)), page.source
    end
  end

  def test_rewrites_links_and_leaves_a_shell_fence_unchanged
    pages = [
      { 'source' => 'docs/PITCH.md', 'slug' => 'Pitch', 'section' => 'Start' },
      { 'source' => 'docs/aim/aim_plan.md', 'slug' => 'AIM-Plan', 'section' => 'Start' }
    ]
    rewritten = Paperboy::WikiRewriter.new(WikiPublishFixtures.catalog(pages))
                                      .rewrite(WikiPublishFixtures.sample_markdown, 'README.md')

    assert_includes rewritten, '[the pitch](Pitch)'
    assert_includes rewritten, '[`docs/aim/aim_plan.md`](AIM-Plan)'
    assert_includes rewritten, '[`docs/PITCH.md`](Pitch) in prose.'
    assert_includes rewritten, '[the site](https://example.com/docs/PITCH.md)'
    assert_includes rewritten, "```bash\ncat docs/PITCH.md\n```"
    assert_includes rewritten, 'Read [`docs/aim/aim_plan.md`](AIM-Plan) before doing anything.'
  end

  def test_leaves_an_unmanaged_page_and_a_migrated_page
    cat = WikiPublishFixtures.catalog([
                                        { 'source' => 'docs/PITCH.md', 'slug' => 'Pitch',
                                          'section' => 'Start', 'keep' => false }
                                      ])
    staged = { 'Home.md' => "<!-- paperboy-wiki-source: generated-home -->\n" }
    existing = {
      'Home.md' => "<!-- paperboy-wiki-source: generated-home -->\n",
      'Pitch.md' => "<!-- paperboy-wiki-source: docs/PITCH.md -->\n",
      'Notes.md' => "# Notes\n",
      'Retired.md' => "<!-- paperboy-wiki-source: docs/OLD.md -->\n"
    }

    plan = Paperboy::WikiPlanner.new(cat).classify(staged, existing)

    assert_includes plan['retain'], 'Pitch.md'
    assert_includes plan['unmanaged'], 'Notes.md'
    assert_equal ['Retired.md'], plan['delete']
    refute_includes plan['delete'], 'Notes.md'
  end

  def test_missing_migrated_source_stays_on_the_home_page
    cat = WikiPublishFixtures.catalog([
                                        { 'source' => 'docs/PITCH.md', 'slug' => 'Pitch',
                                          'section' => 'Start', 'keep' => false }
                                      ])

    Dir.mktmpdir do |root|
      pages = Paperboy::WikiRenderer.new(cat, repo_html_url: REPO_URL).render(root)

      refute_includes pages.keys, 'Pitch.md'
      assert_includes pages.fetch('Home.md'), '](Pitch)'
      assert_includes pages.fetch('Home.md'), 'paperboy-wiki-source: generated-home'
    end
  end

  def test_missing_kept_source_is_refused
    cat = WikiPublishFixtures.catalog([
                                        { 'source' => 'AGENTS.md', 'slug' => 'Agents',
                                          'section' => 'Start', 'keep' => true }
                                      ])

    Dir.mktmpdir do |root|
      assert_raises(Paperboy::WikiCatalog::Refused) do
        Paperboy::WikiRenderer.new(cat, repo_html_url: REPO_URL).render(root)
      end
    end
  end

  def test_template_front_matter_is_omitted_from_the_wiki_page
    cat = WikiPublishFixtures.catalog([
                                        { 'source' => 'bug.md', 'slug' => 'Bug', 'section' => 'Start',
                                          'keep' => true, 'strip_front_matter' => true }
                                      ])

    Dir.mktmpdir do |root|
      File.write(File.join(root, 'bug.md'), "---\nname: Bug\n---\n\n## Problem\n\nBroken.\n")
      page = Paperboy::WikiRenderer.new(cat, repo_html_url: REPO_URL).render(root).fetch('Bug.md')

      refute_includes page, 'name: Bug'
      assert_includes page, '## Problem'
      assert_includes page, 'paperboy-wiki-source: bug.md'
    end
  end

  def test_help_lists_apply
    output, status = Open3.capture2e(File.join(ROOT, 'bin/wiki-publish'), '--help')

    assert_equal 0, status.exitstatus
    assert_includes output, '--apply'
  end
end
