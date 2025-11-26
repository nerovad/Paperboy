# lib/generators/paperboy_form/paperboy_form_generator.rb
require "rails/generators"

module PaperboyForm
  class PaperboyFormGenerator < Rails::Generators::NamedBase
    source_root File.expand_path("templates", __dir__)

    # MODEL
    def create_model
      template "model.rb.tt", File.join("app/models", "#{file_name}.rb")
    end

    # MIGRATION
    def create_migration
      timestamp = Time.now.utc.strftime("%Y%m%d%H%M%S")
      template "migration.rb.tt", File.join("db/migrate", "#{timestamp}_create_#{plural_table_name}.rb")
    end

    # CONTROLLER
    def create_controller
      template "controller.rb.tt", File.join("app/controllers", "#{plural_file_name}_controller.rb")
    end

    # VIEWS (only 'new')
    def create_views
      dir = File.join("app/views", plural_file_name)
      empty_directory dir
      template "views/new.html.erb.tt", File.join(dir, "new.html.erb")
    end

    def add_sidebar_link
      sidebar = "app/views/shared/_sidebar.html.erb"
      return unless File.exist?(sidebar)

      label  = class_name.titleize
      helper = "new_#{file_name}_path"

      # This is the line we want inside the forms array
      key     = %[["#{label}", #{helper}]]
      snippet = %(      ["#{label}", #{helper}],\n)

      content = File.read(sidebar)

      # Don’t add it again if it's already present
      return if content.include?(key)

      # Insert before the closing "] %>" of the forms array
      insert_into_file sidebar,
                      snippet,
                      before: /^\s*\]\s*%>/
    end

    # ROUTES
    def add_routes
      route "resources :#{plural_file_name}"
    end
  end
end
