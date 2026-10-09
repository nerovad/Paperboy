# frozen_string_literal: true

# Which search a person starred as their Paperboy start page: 'advanced' opens
# the Form Library, anything else — including never having chosen — opens the
# home page and its Quick Search sidebar.
class AddDefaultSearchModeToUserSettings < ActiveRecord::Migration[8.1]
  def change
    add_column :user_settings, :default_search_mode, :string
  end
end
