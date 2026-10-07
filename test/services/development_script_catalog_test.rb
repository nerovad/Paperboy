# frozen_string_literal: true

require 'test_helper'

class DevelopmentScriptCatalogTest < ActiveSupport::TestCase
  test 'run model uses the namespaced table created by the migration' do
    assert_equal 'development_runs', Development::Run.table_name
  end

  test 'catalog contains only allowlisted bin scripts' do
    scripts = Development::ScriptCatalog.scripts
    bins = scripts.map { |script| script[:bin] }

    assert_equal scripts.map { |script| script[:key] }.uniq.length, scripts.length
    assert(scripts.all? { |script| Rails.root.join('bin', script[:bin]).file? })
    refute_includes bins, 'gitea-common'
    refute_includes bins, 'shell-init'
  end

  test 'off-menu bins and local start and stop are absent' do
    scripts = Development::ScriptCatalog.scripts
    bins = scripts.map { |script| script[:bin] }
    keys = scripts.map { |script| script[:key] }

    Development::ScriptCatalog::OFF_MENU_BINS.each { |bin| refute_includes bins, bin }
    refute_includes bins, 'dev-local'
    refute_includes keys, 'start_local'
    refute_includes keys, 'stop_local'
    refute_includes Development::ScriptCatalog.groups, 'workstation'
  end

  test 'menu shows dev deploy and tag and hides stage production and aim' do
    visible = Development::ScriptCatalog.groups.flat_map do |group|
      Development::ScriptCatalog.for_group(group).map { |script| script[:key] }
    end

    visible_deploys = Development::ScriptCatalog.for_group('deployments').map { |script| script[:key] }

    assert_equal %w[tag_commit deploy_dev], visible_deploys
    assert_includes visible, 'deploy_dev'
    assert_includes visible, 'tag_commit'
    %w[deploy_stage deploy_production deploy_aim_workers].each do |key|
      script = Development::ScriptCatalog.find(key)
      assert script, key
      assert_equal false, script[:menu]
      assert_equal 'deploy', script[:feature]
      refute_includes visible, key
    end
  end

  test 'command builder creates an argv array rooted in Paperboy' do
    script = Development::ScriptCatalog.find('deploy_stage')
    command = Development::CommandBuilder.new(script, ['v1.2.3']).to_a

    assert_equal false, script[:menu]
    assert_equal Rails.root.join('bin', 'deploy-stage').to_s, command.first
    assert_equal ['v1.2.3'], command.drop(1)
  end

  test 'catalog validates required values before queueing a command' do
    script = Development::ScriptCatalog.find('deploy_production')

    error = assert_raises(ArgumentError) { script[:arguments].call({ tag: '' }) }

    assert_equal 'Release tag is required.', error.message
  end

  test 'pull request catalog entry builds explicit Gitea arguments' do
    script = Development::ScriptCatalog.find('create_pull_request')

    assert_equal 'gitea', script[:feature]
    assert script[:confirm].present?
    assert_equal ['--title', 'Improve docs', '--body', 'Details', '--head', 'feature/docs',
                  '--base', 'master', '--issue', '41'],
                 script[:arguments].call(title: 'Improve docs', body: 'Details',
                                         head: 'feature/docs', base: 'master', issue: '41')
  end

  test 'gitea writes stay on the menu behind the gitea grant' do
    %w[create_issue update_issue clean_worktree create_pull_request status_report].each do |key|
      script = Development::ScriptCatalog.find(key)

      assert script, key
      assert_equal 'gitea', script[:feature]
      assert Development::ScriptCatalog.menu?(script)
    end

    create_issue = Development::ScriptCatalog.find('create_issue')
    update_issue = Development::ScriptCatalog.find('update_issue')

    assert create_issue[:confirm].present?
    assert_equal 'apply', update_issue[:confirm_when]
    assert update_issue[:confirm].present?
    assert_equal ['--issue', '41', '--add-label', 'area:forms'],
                 update_issue[:arguments].call(issue: '41', labels: 'area:forms')
    error = assert_raises(ArgumentError) { update_issue[:arguments].call(issue: '41', apply: '1') }
    assert_equal 'At least one update is required.', error.message
    assert_nil Development::ScriptCatalog.find('status_report')[:confirm]
  end

  test 'worktree clean builds a confirmed gitea command' do
    script = Development::ScriptCatalog.find('clean_worktree')
    assert script[:confirm].present?
    arguments = script[:arguments].call(issue: '41')
    command = Development::CommandBuilder.new(script, arguments).to_a

    assert_equal [Rails.root.join('bin', 'wt').to_s, 'clean', '41'], command

    error = assert_raises(ArgumentError) { script[:arguments].call(issue: '') }

    assert_equal 'Issue must be a number.', error.message
  end

  test 'script features are the five development grants' do
    declared = AppFeature.for('development').map { |feature| feature[:key] }

    assert_equal %w[local environment gitea deploy csr], declared
    Development::ScriptCatalog.scripts.each do |script|
      assert_includes declared, script[:feature], script[:key]
    end
    assert_equal 'local', Development::ScriptCatalog.find('unit_test')[:feature]
    assert_equal 'deploy', Development::ScriptCatalog.find('tag_commit')[:feature]
    assert_equal 'deploy', Development::ScriptCatalog.find('deploy_dev')[:feature]
    assert_equal 'csr', Development::ScriptCatalog.find('generate_csr')[:feature]
    assert Development::ScriptCatalog.find('generate_csr')[:confirm].present?
    assert Development::ScriptCatalog.find('deploy_dev')[:confirm].present?
  end
end

class DevelopmentIssueArgumentTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test 'create issue renders the selected template and can skip the project' do
    script = Development::ScriptCatalog.find('create_issue')
    answers = {
      'feature' => {
        'problem_or_opportunity' => 'People need one issue shape.',
        'proposed_capability' => 'The form follows the template.',
        'acceptance_criteria' => 'Form sections match the template.'
      }
    }

    args = script[:arguments].call(issue_type: 'feature', title: 'Add portal', answers: answers)
    body = args[args.index('--body') + 1]

    assert_equal ['--type', 'feature', '--title', 'Add portal'], args.first(4)
    assert_includes body, '## Problem or opportunity'
    assert_includes body, 'People need one issue shape.'
    assert_includes args, '--no-milestone'
    assert_equal ['--type', 'bug', '--title', 'Fix report', '--body', bug_body, '--milestone', '2026.10',
                  '--no-project'],
                 script[:arguments].call(issue_type: 'bug', title: 'Fix report', answers: bug_answers,
                                         milestone: '2026.10', project: '__none__')
    error = assert_raises(ArgumentError) { script[:arguments].call(issue_type: 'bug', title: 'Fix report') }
    assert_includes error.message, 'Problem is required.'
  end

  test 'update issue plans labels milestone project and column' do
    script = Development::ScriptCatalog.find('update_issue')

    assert_equal ['--issue', '41', '--add-label', 'area:forms', '--remove-label', 'bug', '--milestone', 'Phase',
                  '--project', 'Powerpuff Girls', '--column', 'In Progress', '--apply'],
                 script[:arguments].call(issue: '41', add_labels: ['area:forms'], remove_labels: 'bug',
                                         milestone: 'Phase', project: 'Powerpuff Girls',
                                         column: 'In Progress', apply: '1')
  end

  private

  def bug_answers
    {
      'bug' => {
        'problem' => 'The report is blank.',
        'steps_to_reproduce' => 'Open the report.',
        'expected_behavior' => 'Rows appear.',
        'actual_behavior' => 'The page is empty.',
        'acceptance_criteria' => 'Rows appear again.'
      }
    }
  end

  def bug_body
    Paperboy::Gitea::IssueTemplate.render('bug', bug_answers.fetch('bug'))
  end
end
