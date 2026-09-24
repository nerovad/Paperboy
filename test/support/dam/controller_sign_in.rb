# frozen_string_literal: true

module Dam
  # Signs a controller test in as a user holding Digital Asset Management and
  # exactly the given feature grants, by stubbing the permission lookups the
  # ACL helpers read rather than building groups and grants in the database.
  module ControllerSignIn
    # +group_ids+ and +org_chain+ are what the DAM access rules see the user
    # as; left out, they belong to no group and sit nowhere in the org chart.
    def sign_in_to_dam(features, employee_id: 1, group_ids: [], org_chain: {})
      session[:user] = { 'employee_id' => employee_id, 'email' => 'employee@example.com',
                         'first_name' => 'Test', 'last_name' => 'User' }
      feature_keys = features.to_set
      applications = Set['digital_asset_management']
      @controller.define_singleton_method(:current_user_group_names) { Set.new }
      @controller.define_singleton_method(:current_user_group_ids) { group_ids }
      @controller.define_singleton_method(:current_user_org_chain) { org_chain }
      @controller.define_singleton_method(:current_user_feature_permission_keys) { feature_keys }
      @controller.define_singleton_method(:current_user_application_permission_keys) { applications }
      @controller.define_singleton_method(:current_user_dropdown_permissions) { Set.new }
    end
  end
end
