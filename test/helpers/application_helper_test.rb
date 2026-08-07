# frozen_string_literal: true

require 'test_helper'

class ApplicationHelperTest < ActionView::TestCase
  self.fixture_table_names = []

  test 'environment badge labels localhost separately' do
    assert_equal(
      { label: 'LOCALHOST', css_class: 'is-localhost' },
      environment_badge(host: 'localhost', rails_env: 'development')
    )
  end

  test 'environment badge labels development host' do
    assert_equal(
      { label: 'Development', css_class: 'is-development' },
      environment_badge(host: 'dev-gsa-forms', rails_env: 'development')
    )
  end

  test 'environment badge labels staging host' do
    assert_equal(
      { label: 'Stage', css_class: 'is-staging' },
      environment_badge(host: 'stage-gsa-forms', rails_env: 'staging')
    )
  end

  test 'environment badge is hidden in production' do
    assert_nil environment_badge(host: 'gsa-forms', rails_env: 'production')
  end

  test 'app switcher lists Paperboy first and secondary apps alphabetically' do
    stub(:can_access_app?, true) do
      labels = paperboy_apps.map { |app| app.fetch(:label) }

      assert_equal 'Paperboy', labels.first
      assert_equal labels.drop(1).sort_by(&:downcase), labels.drop(1)
    end
  end
end
