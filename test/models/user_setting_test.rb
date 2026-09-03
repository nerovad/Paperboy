# frozen_string_literal: true

require 'test_helper'

class UserSettingTest < ActiveSupport::TestCase
  test 'notifiable_employee_ids returns only the employees who opted in' do
    UserSetting.create!(employee_id: 'notif-on', inbox_email_notifications: true)
    UserSetting.create!(employee_id: 'notif-off', inbox_email_notifications: false)

    assert_equal ['notif-on'], UserSetting.notifiable_employee_ids(%w[notif-on notif-off])
  end

  test 'notifiable_employee_ids excludes employees with no settings row' do
    # The column defaults to false, so somebody who has never opened Settings
    # must not be emailed.
    assert_empty UserSetting.notifiable_employee_ids(['never-visited-settings'])
  end

  test 'notifiable_employee_ids only considers the ids it was given' do
    UserSetting.create!(employee_id: 'notif-elsewhere', inbox_email_notifications: true)
    UserSetting.create!(employee_id: 'notif-asked', inbox_email_notifications: true)

    assert_equal ['notif-asked'], UserSetting.notifiable_employee_ids(['notif-asked'])
  end

  test 'notifiable_employee_ids handles blank input without querying' do
    assert_empty UserSetting.notifiable_employee_ids(nil)
    assert_empty UserSetting.notifiable_employee_ids([])
    assert_empty UserSetting.notifiable_employee_ids([nil, ''])
  end

  test 'notifiable_employee_ids compares ids as strings' do
    UserSetting.create!(employee_id: '4821', inbox_email_notifications: true)

    assert_equal ['4821'], UserSetting.notifiable_employee_ids([4821])
  end
end
