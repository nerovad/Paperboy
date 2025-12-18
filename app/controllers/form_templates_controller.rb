class FormTemplatesController < ApplicationController
  before_action :require_system_admin
  before_action :set_form_template, only: [:show, :destroy]
  
  def index
    @form_templates = FormTemplate.all.order(created_at: :desc)
    @acl_groups = fetch_acl_groups
    @employees = fetch_employees
  end
  
  def new
    @form_template = FormTemplate.new
    @acl_groups = fetch_acl_groups
  end
  
  def create
    @form_template = FormTemplate.new(form_template_params)
    @form_template.created_by = session.dig(:user, "employee_id")
    
    if @form_template.save
      # Save fields
      if params[:fields].present?
        params[:fields].each_with_index do |field_data, index|
          field = @form_template.form_fields.build(
            label: field_data[:label],
            field_type: field_data[:field_type],
            page_number: field_data[:page_number].to_i,
            position: index,
            required: field_data[:required] == '1',
            options: build_field_options(field_data)
          )
          field.save
        end
      end
      
      # Run the generator command
      class_name = @form_template.class_name
      
      # Execute the Rails generator
      generator_output = `cd #{Rails.root} && bin/rails generate paperboy_form #{class_name} 2>&1`
      
      # Run db:migrate
      migrate_output = `cd #{Rails.root} && bin/rails db:migrate 2>&1`
      
      # Check if generation was successful
      if $?.success?
        # Customize generated model based on submission routing
        customize_generated_model(@form_template)

        # Customize generated controller based on submission routing
        customize_generated_controller(@form_template)

        # Generate dynamic view based on template configuration
        generate_dynamic_view(class_name)

        # Fix the sidebar to put the form in the correct array
        fix_sidebar_placement(class_name)
        
        render json: { 
          success: true, 
          message: "Form created and generated successfully! The form should now appear in your sidebar.",
          redirect: form_templates_path
        }
        else
        # If generation failed, delete the template
        @form_template.destroy
        render json: { 
          success: false, 
          errors: ["Generator failed: #{generator_output}"]
        }, status: :unprocessable_entity
      end
    else
      render json: { 
        success: false, 
        errors: @form_template.errors.full_messages 
      }, status: :unprocessable_entity
    end
  end
  
  def show
    @fields_by_page = @form_template.form_fields.ordered.group_by(&:page_number)
  end
  
  def destroy
    class_name = @form_template.class_name
    table_name = class_name.underscore.pluralize
    path_name = "new_#{table_name.singularize}_path"
    
    # 1. Remove entry from sidebar
    sidebar_file = Rails.root.join("app/views/shared/_sidebar.html.erb")
    if File.exist?(sidebar_file)
      sidebar_content = File.read(sidebar_file)
      
      # Remove the line containing this form's path
      updated_content = sidebar_content.lines.reject do |line|
        line.include?(path_name)
      end.join
      
      File.write(sidebar_file, updated_content)
    end
    
    # 2. Generate a migration to drop the table
    migration_name = "Drop#{class_name}"
    generate_output = `cd #{Rails.root} && bin/rails generate migration #{migration_name} 2>&1`
    
    # 3. Find and update the generated migration file
    migration_file = Dir.glob(Rails.root.join("db/migrate/*_#{migration_name.underscore}.rb")).first
    
    if migration_file
      # Write the drop_table migration
      migration_content = <<~RUBY
        class #{migration_name} < ActiveRecord::Migration[7.1]
          def change
            drop_table :#{table_name}
          end
        end
      RUBY
      
      File.write(migration_file, migration_content)
      
      # 4. Run the migration to drop the table
      migrate_output = `cd #{Rails.root} && bin/rails db:migrate 2>&1`
    end
    
    # 5. Run the destroy command to remove generated files
    destroy_output = `cd #{Rails.root} && bin/rails destroy paperboy_form #{class_name} 2>&1`
    
    # 6. Delete the template record
    if @form_template.destroy
      redirect_to form_templates_path, notice: "Form template, generated files, database table, and sidebar entry deleted successfully."
    else
      redirect_to form_templates_path, alert: "Failed to delete form template."
    end
  end
  
  private
  
  def set_form_template 
    @form_template = FormTemplate.find(params[:id])
  end
  
  def fix_sidebar_placement(class_name)
    sidebar = "app/views/shared/_sidebar.html.erb"
    return unless File.exist?(sidebar)
    
    form_template = FormTemplate.find_by(class_name: class_name)
    return unless form_template
    
    label = class_name.titleize
    helper = "new_#{class_name.underscore}_path"
    
    # Read the sidebar content
    sidebar_content = File.read(sidebar)
    
    # First, remove the incorrectly placed line (generator puts it at the very end)
    incorrect_line = %(      ["#{label}", #{helper}],)
    sidebar_content.gsub!(/^\s*#{Regexp.escape(incorrect_line)}\s*\n/, '')
    
    if form_template.restricted?
      # Add to restricted_forms array with group requirement
      group_name = form_template.acl_group_name
      line = %(      ["#{label}", #{helper}, ["#{group_name}"]],\n)
      
      # Find the restricted_forms array and insert before its closing ]
      # Look for the ] that comes after restricted_forms but before "# Build available forms"
      sidebar_content.sub!(
        /(restricted_forms = \[.*?)(^\s*\])/m,
        "\\1#{line}\\2"
      )
    else
      # Add to public_forms array
      line = %(      ["#{label}", #{helper}],\n)
      
      # Find the public_forms array and insert before its closing ]
      # Look for the ] that comes after public_forms but before "# Restricted forms"
      sidebar_content.sub!(
        /(public_forms = \[.*?)(^\s*\])/m,
        "\\1#{line}\\2"
      )
    end
  
    # Write the modified content back
    File.write(sidebar, sidebar_content)
  end

  def form_template_params
    params.require(:form_template).permit(
      :name,
      :access_level,
      :acl_group_id,
      :page_count,
      :submission_type,
      :approval_routing_to,
      :approval_employee_id,
      page_headers: []
    )
  end
  
  def build_field_options(field_data)
    options = {}
    
    case field_data[:field_type]
    when 'text_box'
      options['rows'] = field_data[:rows].to_i if field_data[:rows].present?
    when 'dropdown'
      if field_data[:dropdown_values].present?
        options['values'] = field_data[:dropdown_values].split(',').map(&:strip)
      end
    end
    
    options
  end
  
  def require_system_admin
    unless is_system_admin?
      redirect_to root_path, alert: "Access denied. System administrators only."
    end
  end
  
  def is_system_admin?
    return false unless session[:user_id]
    
    employee_id = session.dig(:user, "employee_id")
    
    result = ActiveRecord::Base.connection.execute(
      "SELECT COUNT(*) as count 
       FROM GSABSS.dbo.Employee_Groups eg
       JOIN GSABSS.dbo.Groups g ON eg.GroupID = g.GroupID
       WHERE eg.EmployeeID = #{employee_id} 
       AND g.Group_Name = 'system_admins'"
    ).first
    
    result && result['count'].to_i > 0
  rescue
    false
  end
  
  def fetch_acl_groups
    result = ActiveRecord::Base.connection.execute(
      "SELECT GroupID, Group_Name FROM GSABSS.dbo.Groups ORDER BY Group_Name"
    )

    result.map { |row| [row['Group_Name'], row['GroupID']] }
  rescue
    []
  end

  def fetch_employees
    Employee.order(:Last_Name, :First_Name)
            .map { |e| ["#{e.First_Name} #{e.Last_Name} (#{e.EmployeeID})", e.EmployeeID] }
  rescue
    []
  end

  def customize_generated_model(form_template)
    model_path = Rails.root.join("app/models/#{form_template.file_name}.rb")
    return unless File.exist?(model_path)

    # If submission type is database, remove status enum
    if form_template.submission_type == 'database'
      content = File.read(model_path)
      # Remove the enum block
      content.gsub!(/  enum :status.*?\n  \}/m, '')
      File.write(model_path, content)
    end
    # If submission type is approval, the enum is already there from the template
  end

  def customize_generated_controller(form_template)
    controller_path = Rails.root.join("app/controllers/#{form_template.plural_file_name}_controller.rb")
    return unless File.exist?(controller_path)

    content = File.read(controller_path)

    # Find the create action and customize it based on submission routing
    if form_template.requires_approval?
      # Add routing logic to the create action
      routing_logic = generate_approval_routing_logic(form_template)

      # Replace the redirect in the create action with our custom routing logic
      content.gsub!(
        /redirect_to form_success_path.*$/,
        routing_logic
      )
    end

    File.write(controller_path, content)
  end

  def generate_approval_routing_logic(form_template)
    case form_template.approval_routing_to
    when 'supervisor'
      <<~RUBY.chomp
        # Route to supervisor for approval
        @#{form_template.file_name}.update(status: :pending)
        # TODO: Send notification to supervisor
        redirect_to form_success_path, notice: 'Form submitted and routed to your supervisor for approval.', allow_other_host: false, status: :see_other
      RUBY
    when 'department_head'
      <<~RUBY.chomp
        # Route to department head for approval
        @#{form_template.file_name}.update(status: :pending)
        # TODO: Send notification to department head
        redirect_to form_success_path, notice: 'Form submitted and routed to your department head for approval.', allow_other_host: false, status: :see_other
      RUBY
    when 'employee'
      <<~RUBY.chomp
        # Route to specific employee for approval
        @#{form_template.file_name}.update(status: :pending, approver_id: #{form_template.approval_employee_id})
        # TODO: Send notification to employee with ID #{form_template.approval_employee_id}
        redirect_to form_success_path, notice: 'Form submitted and routed for approval.', allow_other_host: false, status: :see_other
      RUBY
    else
      "redirect_to form_success_path, allow_other_host: false, status: :see_other"
    end
  end
  def generate_dynamic_view(class_name)
    form_template = FormTemplate.find_by(class_name: class_name)
    return unless form_template
    
    view_path = Rails.root.join("app/views/#{form_template.plural_file_name}/new.html.erb")
    
    # Build the dynamic view content
    content = <<~HTML
      <!-- Generated by Paperboy Form Builder -->
      <div class="form-header">
        <h1>#{form_template.name}</h1>
      </div>

      <div class="form-wrapper" data-controller="form-navigation">
        <%= form_with model: @#{form_template.file_name}, local: true do |form| %>

    HTML
    
    # Generate each page
    (1..form_template.page_count).each do |page_num|
      page_header = form_template.page_header(page_num)
      fields_for_page = form_template.form_fields.for_page(page_num)
      
      display_style = page_num == 1 ? "" : " style=\"display:none;\""
      
      content += <<~HTML
            <!-- Page #{page_num}: #{page_header} -->
            <div class="form-page"#{display_style}>
              <h2>#{page_header}</h2>
      HTML
      
      # Add standard fields for pages 1 and 2
      if page_num == 1
        content += generate_employee_info_fields
      elsif page_num == 2
        content += generate_agency_info_fields
      end
      
      # Add custom fields
      if fields_for_page.any?
        content += "        <div class=\"form-row d-flex flex-wrap\">\n"
        
        fields_for_page.each do |field|
          content += generate_field_html(field)
        end
        
        content += "        </div>\n"
      end
      
      content += "      </div>\n\n"
    end
    
    # Add navigation buttons
    content += <<~HTML
          <!-- Navigation Buttons -->
          <div class="navigation-buttons d-flex justify-content-between">
            <div>
              <button type="button" id="prevBtn" data-action="click->form-navigation#prevPage" style="display:none;">Previous</button>
            </div>
            <div>
              <button type="button" id="nextBtn" data-action="click->form-navigation#nextPage">Next</button>
              <%= form.submit "Submit", data: { form_navigation_target: "submitButton" }, style: "display:none;" %>
            </div>
          </div>

          <!-- Progress (#{form_template.page_count} steps) -->
          <div class="progress-wrapper">
            <div class="progress-bar-container">
              <div class="progress-bar" id="progressBar"></div>
            </div>
            <div class="progress-dots">
              <% #{form_template.page_count}.times do |index| %>
                <div class="dot <%= 'active' if index == 0 %>"></div>
              <% end %>
            </div>
          </div>

        <% end %>
      </div>
    HTML
    
    File.write(view_path, content)
  end

  def generate_employee_info_fields
    <<~HTML
          <div class="form-row d-flex flex-wrap">
            <div class="form-group flex-fill">
              <%= form.label :employee_id, "Employee ID" %>
              <%= form.text_field :employee_id,
                    value: @prefill_data[:employee_id],
                    class: "form-control",
                    readonly: true %>
            </div>

            <div class="form-group flex-fill">
              <%= form.label :name, "Name" %>
              <%= form.text_field :name,
                    value: @prefill_data[:name],
                    class: "form-control",
                    readonly: true %>
            </div>

            <div class="form-group flex-fill">
              <%= form.label :phone, "Phone" %>
              <%= form.text_field :phone,
                    value: @prefill_data[:phone],
                    class: "form-control",
                    required: true,
                    placeholder: "e.g. 555-555-5555",
                    title: "Enter a 10-digit phone number like 555-555-5555",
                    data: {
                      controller: "phone",
                      phone_target: "input",
                      action: "input->phone#format paste->phone#format blur->phone#validate"
                    },
                    "aria-describedby": "phoneHelp phoneError",
                    pattern: "\\\\d{3}-\\\\d{3}-\\\\d{4}",
                    inputmode: "numeric",
                    autocomplete: "tel" %>
              <small id="phoneHelp" class="help-text text-muted"></small>
              <div id="phoneError" data-phone-target="error" class="field-error" aria-live="polite"></div>
            </div>

            <div class="form-group flex-fill">
              <%= form.label :email, "Email" %>
              <%= form.text_field :email,
                    value: @prefill_data[:email],
                    class: "form-control",
                    required: true %>
            </div>
          </div>
    HTML
  end

  def generate_agency_info_fields
    <<~HTML
          <div data-controller="gsabss-selects" class="form-row d-flex flex-wrap">
            <div class="form-group">
              <%= form.label :agency, "Agency" %>
              <%= form.select :agency,
                    options_for_select(@agency_options, @prefill_data[:agency]),
                    {},
                    class: "form-control",
                    id: "agency-select",
                    data: {
                      gsabss_selects_target: "agency",
                      action: "change->gsabss-selects#loadDivisions"
                    } %>
            </div>

            <div class="form-group">
              <%= form.label :division, "Division" %>
              <%= form.select :division,
                    options_for_select(@division_options, @prefill_data[:division]),
                    {},
                    class: "form-control",
                    id: "division-select",
                    data: {
                      gsabss_selects_target: "division",
                      action: "change->gsabss-selects#loadDepartments"
                    } %>
            </div>

            <div class="form-group">
              <%= form.label :department, "Department" %>
              <%= form.select :department,
                    options_for_select(@department_options, @prefill_data[:department]),
                    {},
                    class: "form-control",
                    id: "department-select",
                    data: {
                      gsabss_selects_target: "department",
                      action: "change->gsabss-selects#loadUnits"
                    } %>
            </div>

            <div class="form-group">
              <%= form.label :unit, "Unit" %>
              <%= form.select :unit,
                    options_for_select(@unit_options, @prefill_data[:unit]),
                    {},
                    class: "form-control",
                    id: "unit-select",
                    data: { gsabss_selects_target: "unit" } %>
            </div>
          </div>
    HTML
  end

  def generate_field_html(field)
    required_attr = field.required ? ", required: true" : ""
    
    case field.field_type
    when 'text'
      <<~HTML
              <div class="form-group flex-fill">
                <%= form.label :#{field.field_name}, "#{field.label}" %>
                <%= form.text_field :#{field.field_name}, class: "form-control"#{required_attr} %>
              </div>
      HTML
    when 'text_box'
      <<~HTML
              <div class="form-group flex-fill">
                <%= form.label :#{field.field_name}, "#{field.label}" %>
                <%= form.text_area :#{field.field_name}, rows: #{field.rows}, class: "form-control"#{required_attr} %>
              </div>
      HTML
    when 'dropdown'
      options = field.dropdown_values.map { |v| "'#{v}'" }.join(', ')
      <<~HTML
              <div class="form-group flex-fill">
                <%= form.label :#{field.field_name}, "#{field.label}" %>
                <%= form.select :#{field.field_name},
                      options_for_select([#{options}]),
                      { include_blank: "Select..." },
                      { class: "form-control"#{required_attr} } %>
              </div>
      HTML
    end
  end
end
