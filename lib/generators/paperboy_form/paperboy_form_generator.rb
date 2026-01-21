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

    # VIEWS (new and show)
    def create_views
      dir = File.join("app/views", plural_file_name)
      empty_directory dir
      template "views/new.html.erb.tt", File.join(dir, "new.html.erb")
      template "views/show.html.erb.tt", File.join(dir, "show.html.erb")
    end

    # PDF GENERATOR SERVICE
    def create_pdf_service
      template "pdf_service.rb.tt", File.join("app/services", "#{file_name}_pdf_generator.rb")
    end

    def add_sidebar_link
      sidebar = "app/views/shared/_sidebar.html.erb"
      return unless File.exist?(sidebar)

      label  = class_name.titleize       # e.g. "Vest Form"
      helper = "new_#{file_name}_path"   # e.g. new_vest_form_path

      # This is the exact line we insert into the forms array
      line = %(      ["#{label}", #{helper}],\n)

      # IMPORTANT: do NOT guard with `include?` here,
      # or destroy/revoke won't be able to reverse it.
      insert_into_file sidebar,
                      line,
                      before: /^\s*\]\s*%>/
    end

    # ROUTES
    def add_routes
      route_content = <<~RUBY
        resources :#{plural_file_name} do
          member do
            get :pdf
            patch :approve
            patch :deny
            patch :update_status
          end
        end
      RUBY
      route route_content
    end
  end
end
