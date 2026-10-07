# frozen_string_literal: true

require 'minitest/autorun'
require 'json'
require 'open3'
require 'tmpdir'
require_relative '../../../../lib/paperboy/gitea/issue_template'

class IssueTemplateTest < Minitest::Test
  TEMPLATE = Paperboy::Gitea::IssueTemplate

  def test_loads_the_four_repository_templates_in_form_order
    types = TEMPLATE.types

    assert_equal %w[bug feature chore infrastructure], types.map(&:key)
    assert_equal ['Bug report', 'Feature request', 'Chore or maintenance', 'Infrastructure request'],
                 types.map(&:name)
    assert_equal types.map(&:key), types.map(&:label)
  end

  def test_templates_do_not_set_a_title_prefix
    Dir.glob(File.expand_path('../../../../.gitea/issue_template/*.md', __dir__)).each do |path|
      refute_match(/^title:/, File.read(path), path)
    end
  end

  def test_field_ids_follow_the_template_sections
    assert_equal %w[problem steps_to_reproduce expected_behavior actual_behavior environment
                    acceptance_criteria additional_context], ids('bug')
    assert_equal %w[problem_or_opportunity proposed_capability acceptance_criteria
                    scope_considerations additional_context], ids('feature')
    assert_equal %w[work_to_perform reason acceptance_criteria risk_and_impact additional_context],
                 ids('chore')
    assert_equal %w[request reason_and_outcome environment required_coordination acceptance_criteria
                    constraints_and_risks], ids('infrastructure')
  end

  def test_prompt_and_check_fields_keep_the_template_labels
    environment = field('bug', 'environment')
    assert_equal %w[environment_or_deployment browser_or_client_if_relevant
                    affected_form_workflow_or_record_type], environment.prompts.map(&:id)

    scope = field('feature', 'scope_considerations')
    assert_equal %w[forms_workflows_or_users_affected data_or_schema_changes
                    permissions_or_security_considerations documentation_or_deployment_notes],
                 scope.prompts.map(&:id)

    coordination = field('infrastructure', 'required_coordination')
    assert_equal ['GSA coordination', 'Network or firewall change', 'Credentials or secret management',
                  'Windows or Docker configuration', 'Deployment or operations documentation'],
                 coordination.options
    assert_equal 'checks', coordination.kind
    refute coordination.content_required
  end

  def test_additional_context_is_the_only_optional_prose
    feature = TEMPLATE.find('feature')
    optional = feature.fields.select(&:optional).map(&:id)
    required = feature.fields.select(&:content_required).map(&:id)

    assert_equal ['additional_context'], optional
    assert_equal %w[problem_or_opportunity proposed_capability acceptance_criteria], required
  end

  def test_render_round_trips_into_a_body_the_same_template_accepts
    body = TEMPLATE.render('infrastructure', infrastructure_answers)

    assert_includes body, "## Request\n\nOpen the port."
    assert_includes body, '- [x] GSA coordination'
    assert_includes body, '- [ ] Network or firewall change'
    assert_includes body, '- Host or service: app-01'
    assert TEMPLATE.valid_body?('infrastructure', body)
  end

  def test_untouched_skeleton_and_missing_sections_are_rejected
    TEMPLATE.types.each do |type|
      errors = TEMPLATE.body_errors(type.key, TEMPLATE.skeleton(type.key))
      refute_empty errors, type.key
    end
    assert_includes TEMPLATE.body_errors('bug', TEMPLATE.skeleton('bug')), 'Problem is required.'
    error = assert_raises(TEMPLATE::Invalid) { TEMPLATE.render('feature', {}) }
    assert_includes error.message, 'Problem or opportunity is required.'
  end

  def test_summary_lists_answer_keys
    summary = TEMPLATE.summary('feature')

    assert_includes summary, '- problem_or_opportunity: Problem or opportunity (required)'
    assert_includes summary, '  - forms_workflows_or_users_affected: Forms, workflows, or users affected'
    assert_includes summary, '- additional_context: Additional context (optional)'
  end

  def test_cli_renders_an_answers_file
    Dir.mktmpdir do |dir|
      path = File.join(dir, 'answers.json')
      File.write(path, JSON.generate(feature_answers))
      stdout, stderr, status = Open3.capture3(
        'ruby', File.expand_path('../../../../lib/paperboy/gitea/issue_template.rb', __dir__),
        'render', '--type', 'feature', '--answers-file', path
      )

      assert status.success?, stderr
      assert_includes stdout, '## Proposed capability'
      assert TEMPLATE.valid_body?('feature', stdout)
    end
  end

  def ids(key) = TEMPLATE.find(key).fields.map(&:id)

  def field(key, id) = TEMPLATE.find(key).fields.find { |item| item.id == id }

  def feature_answers
    {
      'problem_or_opportunity' => 'Three paths file different issues.',
      'proposed_capability' => 'One template fills the form and the script.',
      'acceptance_criteria' => 'The form shows the feature sections.'
    }
  end

  def infrastructure_answers
    {
      'request' => 'Open the port.',
      'reason_and_outcome' => 'The app can be reached.',
      'environment' => { 'host_or_service' => 'app-01' },
      'required_coordination' => ['GSA coordination'],
      'acceptance_criteria' => 'The port is open.',
      'constraints_and_risks' => 'Do this in the maintenance window.'
    }
  end
end

class IssueTemplateAnswersTest < Minitest::Test
  TEMPLATE = Paperboy::Gitea::IssueTemplate

  def test_answers_round_trip_through_render
    rendered = TEMPLATE.render('infrastructure', infrastructure_answers)
    again = TEMPLATE.render('infrastructure', TEMPLATE.answers_for('infrastructure', rendered))

    assert_equal rendered, again
    assert_equal ['GSA coordination'], TEMPLATE.answers_for('infrastructure', rendered)['required_coordination']
  end

  def test_a_checked_criterion_stays_checked
    rendered = TEMPLATE.render('feature', feature_answers)
    checked = rendered.sub('- [ ] The form shows the feature sections.',
                           '- [x] The form shows the feature sections.')

    parsed = TEMPLATE.answers_for('feature', checked)

    assert_includes parsed['acceptance_criteria'], '- [x] The form shows the feature sections.'
    assert_equal checked, TEMPLATE.render('feature', parsed)
  end

  def test_an_unexpected_section_is_refused
    rendered = TEMPLATE.render('feature', feature_answers)
    error = assert_raises(TEMPLATE::Invalid) { TEMPLATE.answers_for('feature', "#{rendered}\n## Notes\n\nKeep this.\n") }

    assert_includes error.message, 'Unexpected section: Notes.'
  end

  def test_type_for_labels_uses_the_template_order
    assert_equal 'bug', TEMPLATE.type_for_labels(%w[feature bug])
    assert_nil TEMPLATE.type_for_labels(['area:forms'])
  end

  private

  def feature_answers
    {
      'problem_or_opportunity' => 'Three paths file different issues.',
      'proposed_capability' => 'One template fills the form and the script.',
      'acceptance_criteria' => 'The form shows the feature sections.'
    }
  end

  def infrastructure_answers
    {
      'request' => 'Open the port.',
      'reason_and_outcome' => 'The app can be reached.',
      'environment' => { 'host_or_service' => 'app-01' },
      'required_coordination' => ['GSA coordination'],
      'acceptance_criteria' => 'The port is open.',
      'constraints_and_risks' => 'Do this in the maintenance window.'
    }
  end
end
