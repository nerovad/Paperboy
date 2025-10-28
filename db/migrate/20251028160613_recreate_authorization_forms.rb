# db/migrate/XXXXXX_recreate_authorization_forms.rb
class RecreateAuthorizationForms < ActiveRecord::Migration[7.0]
  def change
    drop_table :authorization_forms if table_exists?(:authorization_forms)
    
    # We're using authorized_approvers instead
    # authorization_forms views/controllers can be deleted
  end
end
