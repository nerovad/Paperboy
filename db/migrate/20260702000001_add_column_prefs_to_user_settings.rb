class AddColumnPrefsToUserSettings < ActiveRecord::Migration[8.0]
  def change
    # Per-user, per-page column/filter layout for the Inbox and Submissions
    # tables. JSON-serialized (see UserSetting#column_prefs). Nullable so
    # existing rows keep their defaults.
    add_column :user_settings, :column_prefs, :text
  end
end
