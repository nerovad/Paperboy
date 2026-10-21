# frozen_string_literal: true

require 'test_helper'

# The switcher test in ApplicationHelperTest is already at the class-length
# limit. This case is the signed-out one: global ACL grants must not open
# the dropdown before anybody has logged in.
class PaperboyAppsSignedOutTest < ActionView::TestCase
  include ApplicationHelper

  self.fixture_table_names = []

  attr_writer :signed_in

  def current_user
    @signed_in
  end

  test 'a signed-out visitor gets Paperboy and no application dropdown' do
    self.signed_in = false
    labels = paperboy_apps.map { |app| app.fetch(:label) }

    assert_equal ['Paperboy'], labels
  end
end
