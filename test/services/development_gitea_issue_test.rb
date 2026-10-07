# frozen_string_literal: true

require 'test_helper'

class DevelopmentGiteaIssueTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test 'a failed lookup leaves the form blank' do
    Open3.stub(:capture3, ['', 'nope', status(false)]) do
      assert_nil Development::GiteaIssue.for_form('41')
    end
  end

  test 'a matching body fills the template answers' do
    Open3.stub(:capture3, [JSON.generate(payload), '', status(true)]) do
      loaded = Development::GiteaIssue.for_form('41')

      assert_equal 41, loaded[:number]
      assert_equal 'Revise widgets', loaded[:title]
      assert_equal 'feature', loaded[:type]
      assert_equal 'People need one issue shape.', loaded[:answers]['feature']['problem_or_opportunity']
      assert_equal %w[priority:normal feature], loaded[:labels]
      assert_equal 'Phase', loaded[:milestone]
      assert_equal 'Powerpuff Girls', loaded[:project]
      assert_equal 'In Progress', loaded[:column]
      assert_nil loaded[:body_error]
    end
  end

  test 'several projects stay unselected' do
    several = payload.merge('projects' => %w[One Two], 'column' => nil)
    Open3.stub(:capture3, [JSON.generate(several), '', status(true)]) do
      loaded = Development::GiteaIssue.for_form('41')

      assert_nil loaded[:project]
      assert_equal %w[One Two], loaded[:projects]
      assert_nil loaded[:column]
    end
  end

  test 'a body that does not match keeps the title and reports the error' do
    broken = payload.merge('body' => "#{payload.fetch('body')}\n## Notes\n\nKeep this.\n")
    Open3.stub(:capture3, [JSON.generate(broken), '', status(true)]) do
      loaded = Development::GiteaIssue.for_form('41')

      assert_equal 'Revise widgets', loaded[:title]
      assert_nil loaded[:type]
      assert_equal 'Phase', loaded[:milestone]
      assert_includes loaded[:body_error], 'Unexpected section: Notes.'
    end
  end

  test 'an issue without a type label does not choose a template' do
    unlabeled = payload.merge('labels' => ['area:forms'])
    Open3.stub(:capture3, [JSON.generate(unlabeled), '', status(true)]) do
      loaded = Development::GiteaIssue.for_form('41')

      assert_nil loaded[:type]
      assert_equal 'This issue has no bug, feature, chore, or infrastructure label.', loaded[:body_error]
    end
  end

  private

  def payload
    {
      'number' => 41,
      'title' => 'Revise widgets',
      'labels' => %w[priority:normal feature],
      'milestone' => 'Phase',
      'projects' => ['Powerpuff Girls'],
      'column' => 'In Progress',
      'body' => Paperboy::Gitea::IssueTemplate.render('feature', {
                                                        'problem_or_opportunity' => 'People need one issue shape.',
                                                        'proposed_capability' => 'The form follows the template.',
                                                        'acceptance_criteria' => 'Form sections match the template.'
                                                      })
    }
  end

  def status(success)
    Object.new.tap { |result| result.define_singleton_method(:success?) { success } }
  end
end
