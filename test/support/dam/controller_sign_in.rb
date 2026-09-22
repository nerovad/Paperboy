# frozen_string_literal: true

module Dam
  # Signs a controller test in as a user holding Digital Asset Management and
  # exactly the given feature grants, by stubbing the permission lookups the
  # ACL helpers read rather than building groups and grants in the database.
  module ControllerSignIn
    def sign_in_to_dam(features)
      session[:user] = { 'employee_id' => 1, 'email' => 'employee@example.com',
                         'first_name' => 'Test', 'last_name' => 'User' }
      feature_keys = features.to_set
      applications = Set['digital_asset_management']
      @controller.define_singleton_method(:current_user_group_names) { Set.new }
      @controller.define_singleton_method(:current_user_feature_permission_keys) { feature_keys }
      @controller.define_singleton_method(:current_user_application_permission_keys) { applications }
      @controller.define_singleton_method(:current_user_dropdown_permissions) { Set.new }
    end
  end
end
