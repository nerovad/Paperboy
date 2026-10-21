# frozen_string_literal: true

require 'test_helper'

# Entra sign-in stores omniauth.state in the session before the browser leaves
# for Microsoft. A second cookie session drops that key on the way out, and
# the callback then crashes in OmniAuth's secure_compare.
class OmniauthSessionMiddlewareTest < ActiveSupport::TestCase
  test 'one cookie session wraps OmniAuth' do
    names = Rails.application.middleware.map { |entry| entry.klass.name }
    stores = names.each_index.select { |index| names[index] == 'ActionDispatch::Session::CookieStore' }
    omniauth = names.index('OmniAuth::Builder')

    assert_equal 1, stores.size
    assert omniauth
    assert_operator stores.first, :<, omniauth
  end
end
