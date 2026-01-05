class DropBrownMailFormForm < ActiveRecord::Migration[7.1]
  def change
    drop_table :brown_mail_form_forms
  end
end
