# frozen_string_literal: true

require 'test_helper'

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  driven_by :selenium, using: :headless_chrome, screen_size: [1400, 1400]

  def default_url_options
    server = Capybara.current_session.server
    { host: server.host, port: server.port }
  end

  def visit(*args, **options)
    super
    return unless page.has_css?('.pb-modal--startup-warning', wait: 5)

    page.find('.pb-modal--startup-warning button', text: 'Continue').click
  end
end
