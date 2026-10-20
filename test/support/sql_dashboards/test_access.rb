# frozen_string_literal: true

module SqlDashboards
  # The test database has no read-only login. Inside +with_read_only_login+
  # the feature believes it has one, and its connection classes, which were
  # never pointed anywhere else, answer with the test database's own pool.
  module TestAccess
    def with_read_only_login(&block)
      SqlDashboards::Database.stub(:configured?, true, &block)
    end

    def build_query(**attributes)
      SqlDashboards::Query.create!({ name: 'Requests by status', database_key: 'paperboy', chart_type: 'table',
                                     statement: 'SELECT 1 AS n' }.merge(attributes))
    end

    # Signs a controller test in holding exactly the given Paperboy features.
    def sign_in_with_features(*features)
      session[:user] = { 'employee_id' => 102_989, 'email' => 'maria.acosta@example.com',
                         'first_name' => 'Maria', 'last_name' => 'Acosta' }
      keys = features.to_set { |feature| "paperboy:#{feature}" }
      @controller.define_singleton_method(:current_user_group_names) { Set.new }
      @controller.define_singleton_method(:current_user_feature_permission_keys) { keys }
      @controller.define_singleton_method(:current_user_form_permission_keys) { Set.new }
      @controller.define_singleton_method(:current_user_dropdown_permissions) { Set.new }
      @controller.define_singleton_method(:inbox_count) { 0 }
    end
  end
end
