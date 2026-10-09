# frozen_string_literal: true

require 'test_helper'

# The forms a person has taken off their own sidebar.
class UserSettingHiddenFormsTest < ActiveSupport::TestCase
  test 'nobody has hidden anything until they say so' do
    assert_empty UserSetting.hidden_form_keys_for('no-such-employee')
    assert_empty UserSetting.new.hidden_form_key_list
  end

  test 'hiding twice lists the form once, and showing removes only that form' do
    settings = UserSetting.for_employee('555001')
    settings.set_form_hidden('42', true)
    settings.set_form_hidden('42', true)
    settings.set_form_hidden('leave_of_absence', true)

    assert_equal %w[42 leave_of_absence], UserSetting.hidden_form_keys_for('555001')

    settings.set_form_hidden(42, false)

    assert_equal %w[leave_of_absence], UserSetting.hidden_form_keys_for('555001')
  end
end
