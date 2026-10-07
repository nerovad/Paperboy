# frozen_string_literal: true

require 'fileutils'
require 'json'
require 'minitest/autorun'
require 'open3'
require 'shellwords'
require 'tmpdir'
require_relative '../../lib/paperboy/gitea/issue_template'
require_relative '../../lib/paperboy/gitea/pull_request_template'

# Exercises the Gitea workflow scripts against a fake curl. Nothing here
# talks to SQL Server or the live Gitea server.
module GiteaScriptFixture
  REPO_BIN = File.expand_path('../../bin', __dir__)
  FAKE_CURL = File.expand_path('support/fake_gitea_curl.rb', __dir__)

  def prepare_gitea_fixture
    @root = Dir.mktmpdir('gitea-scripts-')
    @bin = File.join(@root, 'bin')
    @fixtures = File.join(@root, 'fixtures')
    @log = File.join(@root, 'curl.log')
    FileUtils.mkdir_p([@bin, @fixtures])
    File.write(@log, '')
    install_fake_commands
    @env_file = File.join(@root, 'gitea.env')
    File.write(@env_file, <<~ENV)
      GITEA_URL=http://gitea.test
      GITEA_TOKEN="test-token"
      GITEA_OWNER=BSS
      GITEA_REPOSITORY=Paperboy
      DATABASE_PASSWORD=super-secret
    ENV
  end

  def install_fake_commands
    curl = File.join(@bin, 'curl')
    File.write(curl, "#!/bin/bash\nexec ruby #{Shellwords.escape(FAKE_CURL)} \"$@\"\n")
    date = File.join(@bin, 'date')
    File.write(date, <<~BASH)
      #!/bin/bash
      if [[ "$*" == *iso-8601* ]]; then
        echo '2026-01-01T00:00:00Z'
      elif [[ "$1" == "-d" && "$2" == *T* ]]; then
        exec /usr/bin/date -d "$2" +%s
      else
        echo 1000000000
      fi
    BASH
    FileUtils.chmod(0o755, [curl, date])
  end

  def cleanup_gitea_fixture
    FileUtils.remove_entry(@root) if @root
  end

  def write_fixture(key, body, total: nil, status: 200)
    payload = { 'status' => status, 'body' => body }
    payload['total'] = total unless total.nil?
    File.write(File.join(@fixtures, "#{key.tr('/', '|')}.json"), JSON.generate(payload))
  end

  def child_env
    {
      'PATH' => "#{@bin}:/usr/bin:/bin",
      'GITEA_ENV_FILE' => @env_file,
      'GITEA_FIXTURES' => @fixtures,
      'CURL_LOG' => @log,
      'HOME' => @root,
      # The fake curl is system Ruby. A parent bundle exec would otherwise
      # make that Ruby load this Gemfile and reject Ruby 3.4.
      'RUBYOPT' => nil,
      'BUNDLE_GEMFILE' => nil,
      'BUNDLE_PATH' => nil,
      'GEM_HOME' => nil,
      'GEM_PATH' => nil
    }
  end

  def run_script(name, *args)
    File.write(@log, '')
    Open3.capture3(child_env, File.join(REPO_BIN, name), *args, chdir: @root)
  end

  def run_bash(script)
    File.write(@log, '')
    Open3.capture3(child_env, 'bash', '-c', script, chdir: @root)
  end

  def requests
    File.read(@log).split(/^---\n/).reject(&:empty?).map do |block|
      block.lines.to_h { |line| line.chomp.split('=', 2) }
    end
  end

  def section(text, title)
    chunk = text.split("\n\n").find { |part| part.start_with?(title) }
    assert chunk, "missing section #{title}\n#{text}"
    chunk
  end
end

class GiteaCommonScriptTest < Minitest::Test
  include GiteaScriptFixture

  def setup
    prepare_gitea_fixture
  end

  def teardown
    cleanup_gitea_fixture
  end

  def test_load_config_keeps_only_gitea_variables
    stdout, stderr, status = run_bash(<<~BASH)
      set -euo pipefail
      source #{Shellwords.escape(File.join(REPO_BIN, 'gitea-common'))}
      gitea_load_config
      if [[ -n ${DATABASE_PASSWORD:-} ]]; then echo LEAKED; exit 1; fi
      printf 'url=%s token=%s\\n' "$GITEA_URL" "$GITEA_TOKEN"
    BASH

    assert status.success?, stderr
    assert_equal "url=http://gitea.test token=test-token\n", stdout
  end

  def test_get_all_follows_pages_until_the_total
    page = Array.new(50) { |index| { 'id' => index + 1, 'name' => "label-#{index}" } }
    write_fixture('GET labels page=1', page, total: 51)
    write_fixture('GET labels page=2', [{ 'id' => 51, 'name' => 'last' }], total: 51)

    stdout, stderr, status = run_bash(<<~BASH)
      set -euo pipefail
      source #{Shellwords.escape(File.join(REPO_BIN, 'gitea-common'))}
      gitea_load_config
      gitea_get_all labels | jq length
    BASH

    assert status.success?, stderr
    assert_equal "51\n", stdout
    urls = requests.map { |request| request.fetch('url') }
    assert(urls.any? { |url| url.include?('limit=50&page=1') })
    assert(urls.any? { |url| url.include?('limit=50&page=2') })
    refute(urls.any? { |url| url.include?('limit=100') })
  end

  def test_http_error_prints_the_response_body
    write_fixture('GET labels page=1', { 'message' => 'nope' }, status: 422)

    _stdout, stderr, status = run_bash(<<~BASH)
      set -euo pipefail
      source #{Shellwords.escape(File.join(REPO_BIN, 'gitea-common'))}
      gitea_load_config
      gitea_get labels
    BASH

    refute status.success?
    assert_includes stderr, 'HTTP 422'
    assert_includes stderr, 'nope'
    assert_equal 'yes', requests.first.fetch('auth')
    refute_includes File.read(@log), 'test-token'
  end
end

class GiteaNewIssueScriptTest < Minitest::Test
  include GiteaScriptFixture

  def setup
    prepare_gitea_fixture
  end

  def teardown
    cleanup_gitea_fixture
  end

  def test_create_sends_labels_milestone_and_project_in_one_request
    write_create_fixtures

    stdout, stderr, status = run_script(
      'new-issue', '--type', 'feature', '--title', 'Add widgets',
      '--body', valid_feature_body, '--milestone', 'Phase'
    )

    assert status.success?, "#{stdout}\n#{stderr}"
    assert_includes stdout, 'Created issue #50'
    payload = JSON.parse(create_request.fetch('data'))
    assert_equal 'Add widgets', payload['title']
    assert_includes payload['body'], '## Problem or opportunity'
    assert_includes payload['body'], 'Widgets are missing.'
    assert_equal [5], payload['labels']
    assert_equal 9, payload['milestone']
    assert_equal [2], payload['projects']
    refute(requests.any? { |request| request['url'].include?('/labels') && request['method'] == 'POST' })
    refute(requests.any? { |request| request['url'].include?('issue_templates') })
  end

  def test_answers_file_renders_the_template_sections
    write_create_fixtures
    path = File.join(@root, 'answers.json')
    File.write(path, JSON.generate(
                       'problem_or_opportunity' => 'Widgets are missing.',
                       'proposed_capability' => 'Add widgets.',
                       'acceptance_criteria' => 'A widget can be added.'
                     ))

    stdout, stderr, status = run_script(
      'new-issue', '--type', 'feature', '--title', 'Add widgets',
      '--answers-file', path, '--no-project'
    )

    assert status.success?, "#{stdout}\n#{stderr}"
    payload = JSON.parse(create_request.fetch('data'))
    assert_includes payload['body'], '## Scope considerations'
    assert_includes payload['body'], '- Forms, workflows, or users affected:'
    refute payload.key?('projects')
  end

  def test_omitted_body_is_refused
    _stdout, stderr, status = run_script('new-issue', '--type', 'feature', '--title', 'Add widgets', '--no-project')

    refute status.success?
    assert_includes stderr, '--answers-file'
    assert_includes stderr, 'problem_or_opportunity'
    refute(requests.any? { |request| request['method'] == 'POST' })
  end

  def test_untouched_template_body_is_refused
    _stdout, stderr, status = run_script(
      'new-issue', '--type', 'feature', '--title', 'Add widgets',
      '--body', Paperboy::Gitea::IssueTemplate.skeleton('feature'), '--no-project'
    )

    refute status.success?
    assert_includes stderr, 'Problem or opportunity is required.'
    refute(requests.any? { |request| request['method'] == 'POST' })
  end

  def test_fields_lists_section_ids_without_calling_gitea
    stdout, stderr, status = run_script('new-issue', '--type', 'chore', '--fields')

    assert status.success?, stderr
    assert_includes stdout, 'work_to_perform'
    assert_empty requests
  end

  def test_missing_label_does_not_create_the_issue
    write_create_fixtures(labels: [{ 'id' => 1, 'name' => 'bug' }])

    _stdout, stderr, status = run_script(
      'new-issue', '--type', 'feature', '--title', 'Add widgets',
      '--body', valid_feature_body, '--no-project'
    )

    refute status.success?
    assert_includes stderr, 'Label was not found: feature'
    refute(requests.any? { |request| request['method'] == 'POST' })
  end

  private

  def valid_feature_body
    Paperboy::Gitea::IssueTemplate.render('feature', {
                                            'problem_or_opportunity' => 'Widgets are missing.',
                                            'proposed_capability' => 'Add widgets.',
                                            'acceptance_criteria' => 'A widget can be added.'
                                          })
  end

  def write_create_fixtures(labels: [{ 'id' => 5, 'name' => 'feature' }])
    write_fixture('GET labels page=1', labels)
    write_fixture('GET milestones name=Phase&state=all page=1', [{ 'id' => 9, 'title' => 'Phase' }])
    write_fixture('GET projects state=all page=1', [{ 'id' => 2, 'title' => 'Powerpuff Girls' }])
    write_fixture('POST issues page=1', { 'number' => 50, 'id' => 300, 'html_url' => 'http://gitea.test/issues/50' })
  end

  def create_request
    requests.find { |request| request['method'] == 'POST' && request['url'].end_with?('/issues') }
  end
end

class GiteaUpdateIssueScriptTest < Minitest::Test
  include GiteaScriptFixture

  def setup
    prepare_gitea_fixture
    write_issue
    write_fixture('GET labels page=1', [
                    { 'id' => 1, 'name' => 'bug' },
                    { 'id' => 5, 'name' => 'feature' },
                    { 'id' => 6, 'name' => 'priority:normal' },
                    { 'id' => 8, 'name' => 'area:forms' }
                  ])
    write_fixture('GET milestones name=Phase&state=all page=1', [{ 'id' => 9, 'title' => 'Phase' }])
    write_fixture('GET projects state=all page=1', [
                    { 'id' => 2, 'title' => 'Powerpuff Girls' },
                    { 'id' => 3, 'title' => 'Other' }
                  ])
    write_fixture('GET projects/2/columns page=1', [{ 'id' => 7, 'title' => 'In Progress' }])
    write_fixture('GET projects/2/columns/7/issues page=1', [])
  end

  def teardown
    cleanup_gitea_fixture
  end

  def test_dry_run_plans_label_project_and_column_changes
    stdout, stderr, status = run_script('update-issue', *update_args)

    assert status.success?, stderr
    assert_includes stdout, '- remove label: area:forms'
    assert_includes stdout, '- add label: priority:normal'
    assert_includes stdout, '- assign milestone: Phase'
    assert_includes stdout, '- assign project: Powerpuff Girls (replaces other projects)'
    assert_includes stdout, '- move to column: In Progress'
    assert_includes stdout, 'Dry run only'
    assert_empty(requests.select { |request| %w[POST PATCH DELETE].include?(request['method']) })
  end

  def test_apply_uses_the_issue_global_id_for_the_column_move
    write_fixture('DELETE issues/10/labels/8 page=1', nil, status: 204)
    write_fixture('POST issues/10/labels page=1', [])
    write_fixture('PATCH issues/10 page=1', {})
    write_fixture('POST projects/2/issues/200/move page=1', {})

    stdout, stderr, status = run_script('update-issue', *update_args, '--apply')

    assert status.success?, "#{stdout}\n#{stderr}"
    deleted = requests.find { |request| request['method'] == 'DELETE' }
    assert_includes deleted.fetch('url'), '/issues/10/labels/8'
    patch = JSON.parse(requests.find { |request| request['method'] == 'PATCH' }.fetch('data'))
    assert_equal 9, patch['milestone']
    assert_equal [2], patch['projects']
    refute patch.key?('state')
    move = requests.find { |request| request['url'].include?('/move') }
    assert_includes move.fetch('url'), '/projects/2/issues/200/move'
    refute_includes move.fetch('url'), '/issues/10/move'
    assert_equal({ 'column_id' => 7 }, JSON.parse(move.fetch('data')))
  end

  def test_same_column_is_left_unchanged
    write_issue(projects: [{ 'id' => 2, 'title' => 'Powerpuff Girls' }])
    write_fixture('GET projects/2/columns/7/issues page=1', [{ 'id' => 200, 'number' => 10 }])

    stdout, stderr, status = run_script(
      'update-issue', '--issue', '10', '--project', 'Powerpuff Girls', '--column', 'In Progress'
    )

    assert status.success?, stderr
    assert_includes stdout, '- no changes required'
    refute_includes stdout, '- move to column'
    refute_includes stdout, 'Audit:'
    assert_empty(requests.select { |request| %w[POST PATCH DELETE].include?(request['method']) })
  end

  def test_column_without_a_project_is_refused
    write_issue(projects: [])

    _stdout, stderr, status = run_script('update-issue', '--issue', '10', '--column', 'In Progress')

    refute status.success?
    assert_includes stderr, 'Pass --project to choose the board for --column.'
  end

  private

  def update_args
    ['--issue', '10', '--add-label', 'priority:normal', '--remove-label', 'area:forms',
     '--milestone', 'Phase', '--project', 'Powerpuff Girls', '--column', 'In Progress']
  end

  def write_issue(projects: [{ 'id' => 3, 'title' => 'Other' }])
    write_fixture('GET issues/10 page=1', {
                    'id' => 200,
                    'number' => 10,
                    'title' => 'Widgets',
                    'labels' => [{ 'id' => 8, 'name' => 'area:forms' }],
                    'milestone' => nil,
                    'projects' => projects
                  })
  end
end

class GiteaNewIssueTypeLabelScriptTest < Minitest::Test
  include GiteaScriptFixture

  def setup
    prepare_gitea_fixture
  end

  def teardown
    cleanup_gitea_fixture
  end

  def test_type_name_on_label_is_refused
    _stdout, stderr, status = run_script(
      'new-issue', '--type', 'feature', '--title', 'Add widgets',
      '--body', valid_feature_body, '--label', 'bug', '--label', 'area:forms', '--no-project'
    )

    refute status.success?
    assert_equal 2, status.exitstatus
    assert_includes stderr, 'Type labels come from --type: bug'
    assert_empty requests
  end

  def test_matching_type_name_on_label_is_refused
    _stdout, stderr, status = run_script(
      'new-issue', '--type', 'feature', '--title', 'Add widgets',
      '--body', valid_feature_body, '--label', 'feature', '--no-project'
    )

    refute status.success?
    assert_equal 2, status.exitstatus
    assert_includes stderr, 'Type labels come from --type: feature'
    assert_empty requests
  end

  def test_ordinary_label_is_sent_with_the_template_label
    write_fixture('GET labels page=1', [
                    { 'id' => 5, 'name' => 'feature' },
                    { 'id' => 8, 'name' => 'area:forms' }
                  ])
    write_fixture('POST issues page=1', { 'number' => 50, 'id' => 300, 'html_url' => 'http://gitea.test/issues/50' })

    _stdout, stderr, status = run_script(
      'new-issue', '--type', 'feature', '--title', 'Add widgets',
      '--body', valid_feature_body, '--label', 'area:forms', '--no-milestone', '--no-project'
    )

    assert status.success?, stderr
    payload = JSON.parse(requests.find { |request| request['method'] == 'POST' }.fetch('data'))
    assert_equal [8, 5], payload['labels']
  end

  private

  def valid_feature_body
    Paperboy::Gitea::IssueTemplate.render('feature', {
                                            'problem_or_opportunity' => 'Widgets are missing.',
                                            'proposed_capability' => 'Add widgets.',
                                            'acceptance_criteria' => 'A widget can be added.'
                                          })
  end
end

class GiteaUpdateIssueContentScriptTest < Minitest::Test
  include GiteaScriptFixture

  def setup
    prepare_gitea_fixture
    write_issue
    write_fixture('GET labels page=1', [
                    { 'id' => 1, 'name' => 'bug' },
                    { 'id' => 5, 'name' => 'feature' },
                    { 'id' => 8, 'name' => 'area:forms' }
                  ])
  end

  def teardown
    cleanup_gitea_fixture
  end

  def test_dry_run_plans_a_title_and_body
    stdout, stderr, status = run_script(
      'update-issue', '--issue', '10', '--title', 'Better widgets', '--type', 'feature', '--body', feature_body
    )

    assert status.success?, stderr
    assert_includes stdout, '- set title: Better widgets'
    assert_includes stdout, '- remove label: bug'
    assert_includes stdout, '- add label: feature'
    assert_includes stdout, '- replace body:'
    assert_includes stdout, 'Widgets are missing.'
    assert_includes stdout, 'Dry run only'
    refute(requests.any? { |request| request['method'] == 'PATCH' })
  end

  def test_apply_patches_title_and_body_without_closing
    write_fixture('DELETE issues/10/labels/1 page=1', nil, status: 204)
    write_fixture('POST issues/10/labels page=1', [])
    write_fixture('PATCH issues/10 page=1', {})

    stdout, stderr, status = run_script(
      'update-issue', '--issue', '10', '--title', 'Better widgets', '--type', 'feature', '--body', feature_body, '--apply'
    )

    assert status.success?, "#{stdout}\n#{stderr}"
    patch = JSON.parse(requests.find { |request| request['method'] == 'PATCH' }.fetch('data'))
    assert_equal 'Better widgets', patch['title']
    assert_includes patch['body'], 'Widgets are missing.'
    refute patch.key?('state')
    deleted = requests.find { |request| request['method'] == 'DELETE' }
    assert_includes deleted.fetch('url'), '/issues/10/labels/1'
    added = JSON.parse(requests.find { |request| request['method'] == 'POST' }.fetch('data'))
    assert_equal [5], added['labels']
    assert_includes stdout, 'Audit:'
  end

  def test_apply_patches_only_the_title_when_the_body_matches
    body = feature_body
    write_issue(body: body, labels: [{ 'id' => 5, 'name' => 'feature' }])
    write_fixture('PATCH issues/10 page=1', {})

    _stdout, stderr, status = run_script(
      'update-issue', '--issue', '10', '--title', 'Better widgets', '--type', 'feature', '--body', body, '--apply'
    )

    assert status.success?, stderr
    patch = JSON.parse(requests.find { |request| request['method'] == 'PATCH' }.fetch('data'))
    assert_equal 'Better widgets', patch['title']
    refute patch.key?('body')
    refute patch.key?('state')
  end

  def test_apply_skips_an_unchanged_title_and_body
    body = feature_body
    write_issue(body: body, labels: [{ 'id' => 5, 'name' => 'feature' }])

    stdout, stderr, status = run_script(
      'update-issue', '--issue', '10', '--title', ' Widgets ', '--type', 'feature', '--body', "#{body}\n", '--apply'
    )

    assert status.success?, stderr
    assert_includes stdout, '- no changes required'
    assert_includes stdout, 'No Gitea state was changed.'
    refute_includes stdout, 'Audit:'
    assert_empty(requests.select { |request| request['method'] == 'PATCH' })
  end

  private

  def feature_body
    Paperboy::Gitea::IssueTemplate.render('feature', {
                                            'problem_or_opportunity' => 'Widgets are missing.',
                                            'proposed_capability' => 'Add widgets.',
                                            'acceptance_criteria' => 'A widget can be added.'
                                          })
  end

  def write_issue(body: nil, title: 'Widgets', labels: [{ 'id' => 1, 'name' => 'bug' }])
    write_fixture('GET issues/10 page=1', {
                    'id' => 200, 'number' => 10, 'title' => title, 'body' => body,
                    'labels' => labels, 'milestone' => nil, 'projects' => []
                  })
  end
end

class GiteaUpdateIssueTypeLabelScriptTest < Minitest::Test
  include GiteaScriptFixture

  def setup
    prepare_gitea_fixture
    write_issue
    write_fixture('GET labels page=1', [
                    { 'id' => 1, 'name' => 'bug' },
                    { 'id' => 5, 'name' => 'feature' },
                    { 'id' => 8, 'name' => 'area:forms' }
                  ])
  end

  def teardown
    cleanup_gitea_fixture
  end

  def test_apply_moves_the_type_label_when_the_body_already_matches
    body = feature_body
    write_issue(body: body)
    write_fixture('DELETE issues/10/labels/1 page=1', nil, status: 204)
    write_fixture('POST issues/10/labels page=1', [])

    stdout, stderr, status = run_script(
      'update-issue', '--issue', '10', '--type', 'feature', '--body', body,
      '--add-label', 'bug', '--add-label', 'area:forms', '--apply'
    )

    assert status.success?, "#{stdout}\n#{stderr}"
    assert_includes stdout, '- remove label: bug'
    assert_includes stdout, '- add label: feature'
    assert_includes stdout, '- add label: area:forms'
    refute_includes stdout, '- replace body:'
    assert_empty(requests.select { |request| request['method'] == 'PATCH' })
    added = JSON.parse(requests.find { |request| request['method'] == 'POST' }.fetch('data'))
    assert_equal [8, 5], added['labels']
  end

  def test_type_label_without_type_is_refused
    _stdout, stderr, status = run_script(
      'update-issue', '--issue', '10', '--add-label', 'feature', '--remove-label', 'bug'
    )

    refute status.success?
    assert_equal 2, status.exitstatus
    assert_includes stderr, 'Type labels come from --type: feature'
    assert_includes stderr, 'Type labels come from --type: bug'
    assert_empty requests
  end

  def test_invalid_body_is_refused_before_a_request
    _stdout, stderr, status = run_script(
      'update-issue', '--issue', '10', '--type', 'feature', '--body', "## Problem or opportunity\n\nOnly one section.\n"
    )

    refute status.success?
    assert_equal 2, status.exitstatus
    assert_includes stderr, 'Proposed capability is required.'
    assert_empty requests
  end

  def test_empty_title_is_refused
    _stdout, stderr, status = run_script('update-issue', '--issue', '10', '--title', '   ')

    refute status.success?
    assert_equal 2, status.exitstatus
    assert_includes stderr, 'Title cannot be empty'
    assert_empty requests
  end

  private

  def feature_body
    Paperboy::Gitea::IssueTemplate.render('feature', {
                                            'problem_or_opportunity' => 'Widgets are missing.',
                                            'proposed_capability' => 'Add widgets.',
                                            'acceptance_criteria' => 'A widget can be added.'
                                          })
  end

  def write_issue(body: nil, title: 'Widgets', labels: [{ 'id' => 1, 'name' => 'bug' }])
    write_fixture('GET issues/10 page=1', {
                    'id' => 200, 'number' => 10, 'title' => title, 'body' => body,
                    'labels' => labels, 'milestone' => nil, 'projects' => []
                  })
  end
end

class GiteaStatusReportScriptTest < Minitest::Test
  include GiteaScriptFixture

  def setup
    prepare_gitea_fixture
    write_fixture('GET issues state=open&type=issues page=1', report_issues, total: 4)
    write_fixture('GET pulls state=open page=1', report_pulls, total: 4)
    write_fixture('GET milestones state=all page=1', [
                    { 'title' => 'Open goal', 'state' => 'open', 'open_issues' => 1, 'closed_issues' => 1 },
                    { 'title' => 'Old goal', 'state' => 'closed', 'open_issues' => 0, 'closed_issues' => 2 }
                  ])
    [10, 11, 12, 14].each do |number|
      body = number == 11 ? [{ 'number' => 9, 'title' => 'Blocker' }] : []
      write_fixture("GET issues/#{number}/dependencies page=1", body)
    end
  end

  def teardown
    cleanup_gitea_fixture
  end

  def test_report_classifies_labels_projects_links_and_instants
    stdout, stderr, status = run_script('status-report', '--stale-days', '30')

    assert status.success?, "#{stdout}\n#{stderr}"
    assert_includes stdout, 'Generated: 2026-01-01T00:00:00Z'
    assert_includes stdout, 'Open issues: 4'
    assert_equal ['- #11: Old unlabeled'], lines(section(stdout, 'Issues missing a type label'))
    priority = section(stdout, 'Issues missing a priority label')
    assert_includes priority, '- #10: Recent feature'
    assert_includes priority, '- #11: Old unlabeled'
    assert_includes priority, '- #12: Blocked labeled'
    refute_includes priority, '#14'
    assert_includes section(stdout, 'Issues not on a project'), '- #10: Recent feature'
    refute_includes section(stdout, 'Issues not on a project'), '#14'
    assert_equal ['- #12: Blocked labeled'], lines(section(stdout, 'Blocked issues'))
    assert_equal ['- #11: Old unlabeled (depends on #9)'],
                 lines(section(stdout, 'Issues with dependency blockers'))
    assert_equal ['- #11: Old unlabeled'], lines(section(stdout, 'Stale issues'))
    assert_equal ['- #22: No link'], lines(section(stdout, 'Pull requests without a linked issue'))
    linked = section(stdout, 'Pull requests with a link and no closing keyword')
    assert_includes linked, '- #21: WIP'
    assert_includes linked, '- #23: Linked only'
    refute_includes linked, '#20'
    refute_includes linked, '#22'
    assert_equal ['- #21: WIP'], lines(section(stdout, 'Draft pull requests'))
    assert_includes section(stdout, 'Pull requests that are not mergeable'), '- #22: No link'
    assert_includes section(stdout, 'Pull requests with requested reviewers'), '- #23: Linked only'
    assert_includes stdout, '- Open goal [open]: 50% complete (1 open, 1 closed)'
    assert_includes stdout, '- Old goal [closed]: 100% complete (0 open, 2 closed)'
    assert_includes stdout, 'Read-only report: no Gitea state was changed.'
  end

  private

  def lines(chunk)
    chunk.lines.map(&:chomp).reject { |line| line.empty? || !line.start_with?('- ') }
  end

  def report_issues
    [
      issue(10, 'Recent feature', ['feature'], stale: false),
      issue(11, 'Old unlabeled', [], milestone: true, project: true, stale: true),
      issue(12, 'Blocked labeled', %w[blocked bug], stale: false),
      issue(14, 'Typed fully', ['chore', 'priority:low', 'area:inbox'], milestone: true, project: true, stale: false)
    ]
  end

  def issue(number, title, labels, milestone: false, project: false, stale: false)
    {
      'number' => number,
      'title' => title,
      'labels' => labels.map { |name| { 'name' => name } },
      'milestone' => (milestone ? { 'id' => 1, 'title' => 'M' } : nil),
      'projects' => (project ? [{ 'id' => 2, 'title' => 'Powerpuff Girls' }] : nil),
      'updated_at' => stale ? '2001-09-09T01:46:39Z' : '2001-09-09T01:46:41Z'
    }
  end

  def report_pulls
    [
      pull(20, 'Closes work', 'Closes #10', draft: false, mergeable: true, reviewers: [], stale: false),
      pull(21, 'WIP', 'see /issues/11', draft: true, mergeable: false, reviewers: ['ada'], stale: true),
      pull(22, 'No link', 'just text', draft: false, mergeable: false, reviewers: [], stale: false),
      pull(23, 'Linked only', 'Related to #10', draft: false, mergeable: true, reviewers: ['bea'], stale: false)
    ]
  end

  def pull(number, title, body, draft:, mergeable:, reviewers:, stale:)
    {
      'number' => number,
      'title' => title,
      'body' => body,
      'draft' => draft,
      'mergeable' => mergeable,
      'requested_reviewers' => reviewers.map { |login| { 'login' => login } },
      'updated_at' => stale ? '2001-09-09T01:46:39Z' : '2001-09-09T01:46:41Z'
    }
  end
end

class GiteaLookupsScriptTest < Minitest::Test
  include GiteaScriptFixture

  def setup
    prepare_gitea_fixture
    write_fixture('GET labels page=1', [{ 'id' => 26, 'name' => 'bug' }])
    write_fixture('GET milestones state=open page=1', [{ 'id' => 1, 'title' => 'Phase' }])
    write_fixture('GET projects state=all page=1', [{ 'id' => 2, 'title' => 'Powerpuff Girls' }])
    write_fixture('GET projects/2/columns page=1', [{ 'id' => 7, 'title' => 'In Progress' }])
  end

  def teardown
    cleanup_gitea_fixture
  end

  def test_prints_labels_milestones_and_project_columns
    stdout, stderr, status = run_script('gitea-lookups')

    assert status.success?, stderr
    payload = JSON.parse(stdout)
    label_names = payload['labels'].map { |row| row['name'] }
    milestone_titles = payload['milestones'].map { |row| row['title'] }
    project = payload['projects'].first
    column_titles = project['columns'].map { |column| column['title'] }
    assert_equal ['bug'], label_names
    assert_equal ['Phase'], milestone_titles
    assert_equal 'Powerpuff Girls', project['title']
    assert_equal ['In Progress'], column_titles
  end
end

class GiteaCreatePullRequestScriptTest < Minitest::Test
  include GiteaScriptFixture

  def setup
    prepare_gitea_fixture
  end

  def teardown
    cleanup_gitea_fixture
  end

  def test_answers_file_posts_closes_without_refs
    write_pull_fixture
    path = File.join(@root, 'answers.json')
    File.write(path, JSON.generate(pull_answers))

    stdout, stderr, status = run_script(
      'create-pull-request', '--title', 'Align pull requests (#64)',
      '--head', 'issue/64-align', '--answers-file', path
    )

    assert status.success?, "#{stdout}\n#{stderr}"
    assert_includes stdout, 'Created pull request #70'
    payload = JSON.parse(requests.last.fetch('data'))
    assert_equal 'issue/64-align', payload['head']
    assert_equal 'master', payload['base']
    assert_includes payload['body'], 'Closes #64'
    refute_includes payload['body'], 'Refs #'
  end

  def test_issue_flag_fills_a_blank_closes_line
    write_pull_fixture
    body = Paperboy::Gitea::PullRequestTemplate.render(pull_answers).sub('Closes #64', 'Closes #')

    stdout, stderr, status = run_script(
      'create-pull-request', '--title', 'Align pull requests (#64)',
      '--head', 'issue/64-align', '--body', body, '--issue', '64'
    )

    assert status.success?, "#{stdout}\n#{stderr}"
    posted = JSON.parse(requests.last.fetch('data'))['body']
    assert_includes posted, 'Closes #64'
    refute_includes posted, 'Refs #'
  end

  def test_a_different_issue_number_is_refused
    body = Paperboy::Gitea::PullRequestTemplate.render(pull_answers)

    _stdout, stderr, status = run_script(
      'create-pull-request', '--title', 'Align pull requests (#64)',
      '--head', 'issue/64-align', '--body', body, '--issue', '65'
    )

    refute status.success?
    assert_includes stderr, 'not #65'
    assert_empty requests
  end

  def test_omitted_body_and_the_empty_template_are_refused
    _stdout, stderr, status = run_script(
      'create-pull-request', '--title', 'Align pull requests', '--head', 'issue/64-align'
    )

    refute status.success?
    assert_includes stderr, 'summary'
    assert_empty requests
    _stdout, stderr, status = run_script(
      'create-pull-request', '--title', 'Align pull requests', '--head', 'issue/64-align',
      '--body', Paperboy::Gitea::PullRequestTemplate.skeleton
    )
    refute status.success?
    assert_includes stderr, 'Summary is required.'
    assert_empty requests
  end

  def test_fields_lists_section_ids_without_calling_gitea
    stdout, stderr, status = run_script('create-pull-request', '--fields')

    assert status.success?, stderr
    assert_includes stdout, 'checks_run'
    assert_empty requests
  end

  private

  def write_pull_fixture
    write_fixture('POST pulls page=1', { 'number' => 70, 'html_url' => 'http://gitea.test/pulls/70' })
  end

  def pull_answers
    {
      'summary' => 'Share one pull request body.',
      'issue' => '64',
      'implementation_notes' => 'Bash still posts the request.',
      'verification' => { 'checks_run' => 'ruby gitea_workflow_test.rb' }
    }
  end
end

class GiteaIssueScriptTest < Minitest::Test
  include GiteaScriptFixture

  def setup
    prepare_gitea_fixture
    write_fixture('GET issues/69 page=1', issue_payload)
    write_fixture('GET projects/2/columns page=1', [
                    { 'id' => 5, 'title' => 'Backlog' },
                    { 'id' => 7, 'title' => 'In Progress' }
                  ])
    write_fixture('GET projects/2/columns/5/issues page=1', [{ 'id' => 1, 'number' => 1 }])
    write_fixture('GET projects/2/columns/7/issues page=1', [{ 'id' => 690, 'number' => 69 }])
  end

  def teardown
    cleanup_gitea_fixture
  end

  def test_prints_labels_milestone_project_and_column
    stdout, stderr, status = run_script('gitea-issue', '69')

    assert status.success?, stderr
    payload = JSON.parse(stdout)
    assert_equal %w[feature area:forms], payload['labels']
    assert_equal 'Phase', payload['milestone']
    assert_equal ['Powerpuff Girls'], payload['projects']
    assert_equal 'In Progress', payload['column']
    assert_equal 'Revise widgets', payload['title']
  end

  def test_column_is_blank_without_exactly_one_project
    write_fixture(
      'GET issues/69 page=1',
      issue_payload.merge(
        'milestone' => nil,
        'projects' => [{ 'id' => 2, 'title' => 'One' }, { 'id' => 3, 'title' => 'Two' }]
      )
    )

    stdout, stderr, status = run_script('gitea-issue', '69')

    assert status.success?, stderr
    payload = JSON.parse(stdout)
    assert_nil payload['milestone']
    assert_nil payload['column']
    assert_equal %w[One Two], payload['projects']
  end

  private

  def issue_payload
    {
      'id' => 690,
      'number' => 69,
      'title' => 'Revise widgets',
      'body' => 'text',
      'labels' => [{ 'id' => 5, 'name' => 'feature' }, { 'id' => 8, 'name' => 'area:forms' }],
      'milestone' => { 'id' => 9, 'title' => 'Phase' },
      'projects' => [{ 'id' => 2, 'title' => 'Powerpuff Girls' }]
    }
  end
end
