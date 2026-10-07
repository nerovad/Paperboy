# frozen_string_literal: true

require 'minitest/autorun'
require 'json'
require 'open3'
require 'tmpdir'
require_relative '../../../../lib/paperboy/gitea/pull_request_template'

class PullRequestTemplateTest < Minitest::Test
  TEMPLATE = Paperboy::Gitea::PullRequestTemplate

  def test_fields_follow_the_template_sections
    fields = TEMPLATE.fields

    assert_equal %w[summary issue implementation_notes verification follow_up_work], fields.map(&:id)
    verification = fields.find { |field| field.id == 'verification' }
    assert_equal 5, verification.options.length
    assert_equal 'Checks run', verification.log_label
    assert_includes TEMPLATE.summary, 'checks_run (required)'
    refute TEMPLATE.fields.find { |field| field.id == 'follow_up_work' }.content_required
  end

  def test_render_closes_the_issue_and_omits_blank_follow_up
    body = TEMPLATE.render(answers.except('follow_up_work'))

    assert_includes body, "## Summary\n\nShare one pull request body."
    assert_includes body, 'Closes #64'
    assert_includes body, '- [x] Tests/checks run are listed below.'
    assert_includes body, '- [ ] No secrets or sensitive data are included.'
    assert_includes body, "```text\nruby pull_request_template_test.rb\n```"
    refute_includes body, '## Follow-up work'
    assert TEMPLATE.valid_body?(body)
  end

  def test_unchanged_help_and_a_conflicting_issue_are_refused
    assert_includes TEMPLATE.body_errors(TEMPLATE.skeleton), 'Summary is required.'
    error = assert_raises(TEMPLATE::Invalid) { TEMPLATE.render(answers.merge('summary' => summary_help)) }
    assert_includes error.message, 'Summary is required.'
    rendered = TEMPLATE.render(answers)
    assert_equal rendered, TEMPLATE.close_issue(rendered, '64')
    conflict = assert_raises(TEMPLATE::Invalid) { TEMPLATE.close_issue(rendered, '65') }
    assert_includes conflict.message, 'not #65'
    opened = TEMPLATE.close_issue(rendered.sub('Closes #64', 'Closes #'), '64')
    assert_includes opened, 'Closes #64'
  end

  def test_cli_renders_an_answers_file
    Dir.mktmpdir do |dir|
      path = File.join(dir, 'answers.json')
      File.write(path, JSON.generate(answers))
      stdout, stderr, status = Open3.capture3(
        'ruby', File.expand_path('../../../../lib/paperboy/gitea/pull_request_template.rb', __dir__),
        'render', '--answers-file', path
      )

      assert status.success?, stderr
      assert_includes stdout, 'Closes #64'
    end
  end

  private

  def answers
    {
      'summary' => 'Share one pull request body.',
      'issue' => '64',
      'implementation_notes' => 'Bash still posts the request.',
      'verification' => {
        'checks' => ['Tests/checks run are listed below.'],
        'checks_run' => 'ruby pull_request_template_test.rb'
      },
      'follow_up_work' => 'None.'
    }
  end

  def summary_help
    TEMPLATE.fields.find { |field| field.id == 'summary' }.help
  end
end
