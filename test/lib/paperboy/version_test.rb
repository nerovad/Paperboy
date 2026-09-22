# frozen_string_literal: true

require 'test_helper'

class PaperboyVersionTest < ActiveSupport::TestCase
  test 'uses the base version and commit identifier' do
    Paperboy::Version.stub(:commit, '21df93052') do
      assert_equal '2.0.1-21df93052', Paperboy::Version.to_s
    end
  end

  test 'an environment version can identify a packaged build' do
    ENV['PAPERBOY_VERSION'] = '2.1.0-abcdef123'

    assert_equal '2.1.0-abcdef123', Paperboy::Version.to_s
  ensure
    ENV.delete('PAPERBOY_VERSION')
  end
end
