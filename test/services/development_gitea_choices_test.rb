# frozen_string_literal: true

require 'test_helper'

class DevelopmentGiteaChoicesTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test 'a failed lookup leaves the form on text fields' do
    Open3.stub(:capture3, ['', 'nope', status(false)]) do
      assert_nil Development::GiteaChoices.fetch
    end
  end

  test 'a lookup returns the parsed names' do
    Open3.stub(:capture3, ['{"labels":[{"name":"bug"}]}', '', status(true)]) do
      assert_equal({ 'labels' => [{ 'name' => 'bug' }] }, Development::GiteaChoices.fetch)
    end
  end

  private

  def status(success)
    Object.new.tap { |result| result.define_singleton_method(:success?) { success } }
  end
end
