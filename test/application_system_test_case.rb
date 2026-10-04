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

  def sign_in_as_employee(employee_id = 1)
    visit root_path
    page.execute_script(<<~JAVASCRIPT, employee_id)
      const form = document.createElement('form')
      form.method = 'post'
      form.action = '/login'

      const token = document.querySelector('meta[name="csrf-token"]').content
      const authenticity = document.createElement('input')
      authenticity.name = 'authenticity_token'
      authenticity.value = token
      form.appendChild(authenticity)

      const employee = document.createElement('input')
      employee.name = 'id'
      employee.value = arguments[0]
      form.appendChild(employee)

      document.body.appendChild(form)
      form.submit()
    JAVASCRIPT
  end
end
