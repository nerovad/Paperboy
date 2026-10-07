# frozen_string_literal: true

require 'test_helper'

# submit's value is the visible label. Apply must be a button so the label
# stays "Apply changes" while the posted value is still "1".
class DevelopmentHelperTest < ActionView::TestCase
  self.fixture_table_names = []

  test 'update issue apply button posts apply without replacing its label' do
    script = Development::ScriptCatalog.find('update_issue')

    render partial: 'development/runs/card', locals: { script: script }

    assert_select 'button.btn.warning[type=submit][name=apply][value="1"]', text: 'Apply changes' do |buttons|
      button = buttons.first
      assert_equal script[:confirm], button['data-turbo-confirm']
      assert_equal 'Apply issue update', button['data-confirm-title']
      assert_equal 'Apply', button['data-confirm-label']
    end
    assert_select 'input.btn.secondary[type=submit][name=commit][value="Preview changes"]'
    assert_select 'input[name=apply]', count: 0
    assert_select 'input[data-turbo-confirm]', count: 0
    assert_select 'input[name=remove_labels]'
    assert_select 'input[name=project]'
    assert_select 'input[name=column]'
  end

  test 'create issue form follows the repository issue templates' do
    script = Development::ScriptCatalog.find('create_issue')

    render partial: 'development/runs/card', locals: { script: script }

    assert_select 'input#issue_type_bug[type=radio][checked]'
    assert_select 'input#issue_type_feature[type=radio]'
    assert_select 'textarea[name="answers[bug][steps_to_reproduce]"]'
    assert_select 'textarea[name="answers[feature][problem_or_opportunity]"]'
    assert_select 'input[name="answers[infrastructure][required_coordination][]"]'
    assert_select 'textarea[name=body]', count: 0
    assert_select 'input[name=title][required]'
  end

  test 'create pull request form follows the repository template' do
    script = Development::ScriptCatalog.find('create_pull_request')

    render partial: 'development/runs/card', locals: { script: script }

    assert_select 'input[name=title][required]'
    assert_select 'input[name=head][required]'
    assert_select 'input[name=base][value=master]'
    assert_select 'textarea[name="answers[summary]"]'
    assert_select 'input[name="answers[issue]"]'
    assert_select 'textarea[name="answers[implementation_notes]"]'
    assert_select 'input[name="answers[verification][checks][]"]'
    assert_select 'textarea[name="answers[verification][checks_run]"]'
    assert_select 'textarea[name="answers[follow_up_work]"]'
    assert_select 'textarea[name=body]', count: 0
  end

  test 'issue forms use gitea names when the lookup succeeds' do
    script = Development::ScriptCatalog.find('update_issue')
    choices = {
      'labels' => [{ 'name' => 'area:forms' }, { 'name' => 'bug' }, { 'name' => 'feature' }],
      'milestones' => [{ 'title' => 'Phase' }],
      'projects' => [{ 'title' => 'Powerpuff Girls', 'columns' => [{ 'title' => 'In Progress' }] }]
    }

    render partial: 'development/runs/card', locals: { script: script, gitea_choices: choices }

    assert_select 'select[name="add_labels[]"] option', text: 'area:forms'
    assert_select 'select[name="remove_labels[]"] option', text: 'area:forms'
    assert_select 'select[name="add_labels[]"] option', text: 'bug', count: 0
    assert_select 'select[name="remove_labels[]"] option', text: 'feature', count: 0
    assert_select 'p.issue-field-help', text: 'Type labels stay with the template above.'
    assert_select 'select[name=milestone] option', text: 'Phase'
    assert_select 'select[name=project] option', text: 'Powerpuff Girls'
    assert_select 'select[name=column] option', text: 'Powerpuff Girls — In Progress'
  end

  test 'update issue form loads the template fields for the issue' do
    script = Development::ScriptCatalog.find('update_issue')
    issue = {
      number: 41, title: 'Revise widgets', type: 'feature', body_error: nil,
      labels: %w[feature area:forms], milestone: 'Phase', project: 'Powerpuff Girls',
      projects: ['Powerpuff Girls'], column: 'In Progress',
      answers: { 'feature' => { 'problem_or_opportunity' => 'People need one shape.',
                                'scope_considerations' => { 'forms_workflows_or_users_affected' => 'Editors' } } }
    }

    render partial: 'development/runs/card', locals: { script: script, gitea_issue: issue }

    assert_select 'input[name=issue][value="41"]'
    assert_select 'input[name=title][value="Revise widgets"]'
    assert_select 'input#issue_type_feature[type=radio][checked]'
    assert_select 'input#issue_type_unchanged[checked]', count: 0
    assert_select 'button.btn[type=submit][formmethod=get]', text: 'Load issue'
    assert_select 'p.issue-field-help', text: 'Choosing a template sets that type label and removes the other type labels.'
    assert_select 'textarea[name="answers[feature][problem_or_opportunity]"]', text: 'People need one shape.'
    assert_select 'input[name="answers[feature][scope_considerations][forms_workflows_or_users_affected]"][value=Editors]'
    assert_select 'p.issue-field-help', text: 'Current labels: feature, area:forms'
    assert_select 'p.issue-field-help', text: 'Current milestone: Phase'
    assert_select 'p.issue-field-help', text: 'Current project: Powerpuff Girls'
    assert_select 'p.issue-field-help', text: 'Current column: In Progress'
  end

  test 'update issue form keeps the title when the body does not match' do
    script = Development::ScriptCatalog.find('update_issue')
    issue = { number: 41, title: 'Revise widgets', type: nil, answers: {},
              body_error: 'Unexpected section: Notes.' }

    render partial: 'development/runs/card', locals: { script: script, gitea_issue: issue }

    assert_select 'p.issue-field-help', text: 'Unexpected section: Notes.'
    assert_select 'input#issue_type_unchanged[type=radio][checked]'
    assert_select 'input[name=title][value="Revise widgets"]'
  end
end

class DevelopmentIssueLoadHelperTest < ActionView::TestCase
  self.fixture_table_names = []

  test 'loaded issue selects its milestone project and column' do
    script = Development::ScriptCatalog.find('update_issue')
    choices = {
      'labels' => [{ 'name' => 'area:forms' }, { 'name' => 'feature' }],
      'milestones' => [{ 'title' => 'Phase' }],
      'projects' => [
        { 'title' => 'Powerpuff Girls', 'columns' => [{ 'title' => 'In Progress' }, { 'title' => 'Done' }] },
        { 'title' => 'Other', 'columns' => [{ 'title' => 'In Progress' }] }
      ]
    }
    issue = {
      number: 41, title: 'Revise widgets', type: 'feature', labels: %w[feature area:forms],
      milestone: 'Phase', project: 'Powerpuff Girls', projects: ['Powerpuff Girls'],
      column: 'In Progress', answers: {}
    }

    render partial: 'development/runs/card', locals: { script: script, gitea_choices: choices, gitea_issue: issue }

    assert_select 'select[name=milestone] option[selected]', text: 'Phase'
    assert_select 'select[name=project] option[selected]', text: 'Powerpuff Girls'
    assert_select 'select[name=column] option[selected]', text: 'Powerpuff Girls — In Progress'
    assert_select 'select[name=column] option[selected]', text: 'Other — In Progress', count: 0
  end

  test 'create form still offers type labels as extra labels' do
    script = Development::ScriptCatalog.find('create_issue')
    choices = { 'labels' => [{ 'name' => 'bug' }, { 'name' => 'area:forms' }] }

    render partial: 'development/runs/card', locals: { script: script, gitea_choices: choices }

    assert_select 'select[name="extra_labels[]"] option', text: 'bug'
    assert_select 'select[name="extra_labels[]"] option', text: 'area:forms'
  end
end
