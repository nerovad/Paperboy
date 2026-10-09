# frozen_string_literal: true

# The forms a person has taken off their own sidebar, as a JSON list of the
# keys the form ACL knows them by. Hiding is a preference, not a permission:
# the form is still theirs to open from the Form Library or a search.
class AddHiddenFormKeysToUserSettings < ActiveRecord::Migration[8.1]
  def change
    add_column :user_settings, :hidden_form_keys, :text
  end
end
