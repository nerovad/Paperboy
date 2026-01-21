class FormTemplatesController < ApplicationController
  before_action :require_system_admin
  before_action :set_form_template, only: [:show, :edit, :update, :destroy]
  
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

    # Set pending routing steps to pass validation (they'll be saved after the form_template)
    @form_template.pending_routing_steps = params[:routing_steps] if params[:routing_steps].present?

    if @form_template.save
      # Save routing steps
      save_routing_steps(@form_template)

      # Save fields (two-pass: create first, then link conditionals)
      if params[:fields].present?
        # First pass: create all fields, store conditional references
        created_fields = []
        conditional_refs = []

        params[:fields].each_with_index do |field_data, index|
          field = @form_template.form_fields.create!(
            label: field_data[:label],
            field_type: field_data[:field_type],
            page_number: field_data[:page_number].to_i,
            position: index,
            required: field_data[:required] == '1',
            options: build_field_options(field_data),
            restricted_to_type: field_data[:restricted_to_type].presence || 'none',
            restricted_to_employee_id: field_data[:restricted_to_employee_id].presence,
            restricted_to_group_id: field_data[:restricted_to_group_id].presence
          )
          created_fields << field

          # Store conditional reference if present (format: "field_N" where N is index)
          if field_data[:conditional_field_id].present? && field_data[:conditional_values].present?
            conditional_refs << {
              field: field,
              ref: field_data[:conditional_field_id],
              values: Array(field_data[:conditional_values]).reject(&:blank?)
            }
          end
        end

        # Second pass: resolve conditional field references to actual IDs
        conditional_refs.each do |ref_data|
          if ref_data[:ref] =~ /^field_(\d+)$/
            ref_index = $1.to_i
            if created_fields[ref_index]
              ref_data[:field].update!(
                conditional_field_id: created_fields[ref_index].id,
                conditional_values: ref_data[:values]
              )
            end
          elsif ref_data[:ref].to_i > 0
            # Direct ID reference (for edit page)
            ref_data[:field].update!(
              conditional_field_id: ref_data[:ref].to_i,
              conditional_values: ref_data[:values]
            )
          end
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

        # Generate dynamic views based on template configuration
        generate_dynamic_view(class_name)
        generate_dynamic_edit_view(class_name)

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

  def edit
    @acl_groups = fetch_acl_groups
    @employees = fetch_employees
    @fields_by_page = @form_template.form_fields.ordered.group_by(&:page_number)
  end

  def update
    routing_changed = routing_fields_changed?

    if @form_template.update(form_template_params)
      # Rebuild routing steps
      rebuild_routing_steps(@form_template)

      rebuild_form_fields

      # Regenerate the view to reflect field changes (including conditional logic)
      generate_dynamic_view(@form_template.class_name)

      if routing_changed
        customize_generated_model(@form_template)
        customize_generated_controller(@form_template)
        Rails.logger.info "Regenerated controller for #{@form_template.class_name}"
      end

      redirect_to form_template_path(@form_template),
                  notice: routing_changed ?
                    "Form template updated successfully. Controller was regenerated." :
                    "Form template updated successfully."
    else
      @acl_groups = fetch_acl_groups
      @employees = fetch_employees
      @fields_by_page = @form_template.form_fields.ordered.group_by(&:page_number)
      render :edit, status: :unprocessable_entity
    end
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
      :has_dashboard,
      :powerbi_workspace_id,
      :powerbi_report_id,
      page_headers: [],
      inbox_buttons: []
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

    content = File.read(model_path)

    # If submission type is database, remove status enum
    if form_template.submission_type == 'database'
      content.gsub!(/  enum :status.*?\n  \}/m, '')
    elsif form_template.requires_approval? && form_template.routing_steps.any?
      # Generate multi-step status enum
      enum_content = generate_multi_step_enum(form_template)
      content.gsub!(/  enum :status.*?\n  \}/m, enum_content)
    end

    File.write(model_path, content)
  end

  def generate_multi_step_enum(form_template)
    steps = form_template.routing_steps.ordered
    return '' if steps.empty?

    statuses = ["submitted: 0"]

    steps.each_with_index do |step, index|
      step_num = index + 1
      statuses << "step_#{step_num}_pending: #{index * 2 + 1}"
      statuses << "step_#{step_num}_approved: #{index * 2 + 2}" unless step_num == steps.count
    end

    statuses << "approved: #{steps.count * 2}"
    statuses << "denied: #{steps.count * 2 + 1}"

    <<~RUBY.chomp
      enum :status, {
        #{statuses.join(",\n    ")}
      }
    RUBY
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

  def routing_fields_changed?
    return false unless @form_template

    # Check if submission type changed
    return true if @form_template.submission_type != params[:form_template][:submission_type]

    # Check if routing steps changed
    current_steps = @form_template.routing_steps.ordered.map do |step|
      { routing_type: step.routing_type, employee_id: step.employee_id }
    end

    new_steps = (params[:routing_steps] || []).map do |step|
      { routing_type: step[:routing_type], employee_id: step[:employee_id]&.to_i.presence }
    end.reject { |s| s[:routing_type].blank? }

    current_steps != new_steps
  end

  def save_routing_steps(form_template)
    return unless params[:routing_steps].present?

    params[:routing_steps].each do |step_data|
      next if step_data[:routing_type].blank?

      form_template.routing_steps.create!(
        step_number: step_data[:step_number].to_i,
        routing_type: step_data[:routing_type],
        employee_id: step_data[:employee_id].presence
      )
    end
  end

  def rebuild_routing_steps(form_template)
    form_template.routing_steps.destroy_all

    return unless params[:routing_steps].present?

    params[:routing_steps].each_with_index do |step_data, index|
      next if step_data[:routing_type].blank?

      form_template.routing_steps.create!(
        step_number: index + 1,
        routing_type: step_data[:routing_type],
        employee_id: step_data[:employee_id].presence
      )
    end

    # Clear legacy routing fields when using routing steps
    if form_template.routing_steps.any?
      form_template.update_columns(approval_routing_to: nil, approval_employee_id: nil)
    end
  end

  def rebuild_form_fields
    @form_template.form_fields.destroy_all

    if params[:fields].present?
      # First pass: create all fields, store conditional references
      created_fields = []
      conditional_refs = []

      params[:fields].each_with_index do |field_data, index|
        field = @form_template.form_fields.create!(
          label: field_data[:label],
          field_type: field_data[:field_type],
          page_number: field_data[:page_number].to_i,
          position: index,
          required: field_data[:required] == '1',
          options: build_field_options(field_data),
          restricted_to_type: field_data[:restricted_to_type].presence || 'none',
          restricted_to_employee_id: field_data[:restricted_to_employee_id].presence,
          restricted_to_group_id: field_data[:restricted_to_group_id].presence
        )
        created_fields << field

        # Store conditional reference if present
        if field_data[:conditional_field_id].present? && field_data[:conditional_values].present?
          conditional_refs << {
            field: field,
            ref: field_data[:conditional_field_id],
            values: Array(field_data[:conditional_values]).reject(&:blank?)
          }
        end
      end

      # Second pass: resolve conditional field references to actual IDs
      conditional_refs.each do |ref_data|
        if ref_data[:ref] =~ /^field_(\d+)$/
          ref_index = $1.to_i
          if created_fields[ref_index]
            ref_data[:field].update!(
              conditional_field_id: created_fields[ref_index].id,
              conditional_values: ref_data[:values]
            )
          end
        elsif ref_data[:ref].to_i > 0
          # Direct ID reference (for edit page with existing fields)
          ref_data[:field].update!(
            conditional_field_id: ref_data[:ref].to_i,
            conditional_values: ref_data[:values]
          )
        end
      end
    end
  end

  def generate_approval_routing_logic(form_template)
    # Check if using multi-step routing
    if form_template.routing_steps.any?
      return generate_multi_step_routing_logic(form_template)
    end

    # Legacy single-step routing
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

  def generate_multi_step_routing_logic(form_template)
    steps = form_template.routing_steps.ordered
    first_step = steps.first

    step_description = routing_step_description(first_step)
    approver_logic = generate_approver_lookup(first_step)

    <<~RUBY.chomp
      # Multi-step approval routing (#{steps.count} steps)
      # Step 1: #{step_description}
      #{approver_logic}
      @#{form_template.file_name}.update(status: :step_1_pending, approver_id: approver_id)
      # TODO: Send notification to #{step_description}
      redirect_to form_success_path, notice: 'Form submitted and routed to #{step_description} for approval.', allow_other_host: false, status: :see_other
    RUBY
  end

  def generate_approver_lookup(step)
    case step.routing_type
    when 'supervisor'
      <<~RUBY.chomp
        # Look up the submitter's supervisor
        employee = Employee.find_by(EmployeeID: session.dig(:user, "employee_id"))
        approver_id = employee&.Supervisor_ID&.to_s
      RUBY
    when 'department_head'
      <<~RUBY.chomp
        # Look up the submitter's department head
        employee = Employee.find_by(EmployeeID: session.dig(:user, "employee_id"))
        unit = employee ? Unit.find_by(unit_id: employee["Unit"]) : nil
        department = unit ? Department.find_by(department_id: unit["department_id"]) : nil
        approver_id = department&.department_head_id&.to_s
      RUBY
    when 'employee'
      "approver_id = '#{step.employee_id}'"
    else
      "approver_id = nil"
    end
  end

  def routing_step_description(step)
    case step.routing_type
    when 'supervisor'
      'supervisor'
    when 'department_head'
      'department head'
    when 'employee'
      "employee ##{step.employee_id}"
    end
  end
  def generate_dynamic_view(class_name)
    form_template = FormTemplate.find_by(class_name: class_name)
    return unless form_template

    view_path = Rails.root.join("app/views/#{form_template.plural_file_name}/new.html.erb")

    # Determine which Stimulus controllers to attach
    controllers = ["form-navigation"]
    controllers << "conditional-fields" if form_template.form_fields.conditional.any?
    controllers_attr = controllers.join(" ")

    # Build the dynamic view content
    content = <<~HTML
      <!-- Generated by Paperboy Form Builder -->
      <div class="form-header">
        <h1>#{form_template.name}</h1>
      </div>

      <div class="form-wrapper" data-controller="#{controllers_attr}">
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

  def generate_dynamic_edit_view(class_name)
    form_template = FormTemplate.find_by(class_name: class_name)
    return unless form_template

    view_path = Rails.root.join("app/views/#{form_template.plural_file_name}/edit.html.erb")

    # Determine which Stimulus controllers to attach
    controllers = ["form-navigation"]
    controllers << "conditional-fields" if form_template.form_fields.conditional.any?
    controllers_attr = controllers.join(" ")

    # Build the dynamic edit view content
    content = <<~HTML
      <!-- Generated by Paperboy Form Builder -->
      <div class="form-header">
        <h1>Edit #{form_template.name}</h1>
      </div>

      <div class="form-wrapper" data-controller="#{controllers_attr}">
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
        content += generate_employee_info_fields_for_edit(form_template)
      elsif page_num == 2
        content += generate_agency_info_fields_for_edit(form_template)
      end

      # Add custom fields
      if fields_for_page.any?
        content += "        <div class=\"form-row d-flex flex-wrap\">\n"

        fields_for_page.each do |field|
          content += generate_field_html_for_edit(field, form_template)
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
              <%= form.submit "Update", data: { form_navigation_target: "submitButton" }, style: "display:none;" %>
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

  def generate_employee_info_fields_for_edit(form_template)
    <<~HTML
          <div class="form-row d-flex flex-wrap">
            <div class="form-group flex-fill">
              <%= form.label :employee_id, "Employee ID" %>
              <%= form.text_field :employee_id,
                    class: "form-control",
                    readonly: true %>
            </div>

            <div class="form-group flex-fill">
              <%= form.label :name, "Name" %>
              <%= form.text_field :name,
                    class: "form-control",
                    readonly: true %>
            </div>

            <div class="form-group flex-fill">
              <%= form.label :phone, "Phone" %>
              <%= form.text_field :phone,
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
                    class: "form-control",
                    required: true %>
            </div>
          </div>
    HTML
  end

  def generate_agency_info_fields_for_edit(form_template)
    <<~HTML
          <div data-controller="gsabss-selects" class="form-row d-flex flex-wrap">
            <div class="form-group">
              <%= form.label :agency, "Agency" %>
              <%= form.select :agency,
                    options_for_select(@agency_options, @#{form_template.file_name}.agency),
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
                    options_for_select(@division_options, @#{form_template.file_name}.division),
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
                    options_for_select(@department_options, @#{form_template.file_name}.department),
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
                    options_for_select(@unit_options, @#{form_template.file_name}.unit),
                    {},
                    class: "form-control",
                    id: "unit-select",
                    data: { gsabss_selects_target: "unit" } %>
            </div>
          </div>
    HTML
  end

  def generate_field_html_for_edit(field, form_template)
    # Generate restriction check and attributes
    if field.restricted?
      editable_check = generate_editable_check(field)
      required_logic = field.required ? "required: field_#{field.id}_editable && #{field.required}" : ""
      disabled_attr = "disabled: !field_#{field.id}_editable"
      restriction_label = field.restriction_label
    else
      editable_check = nil
      required_logic = field.required ? "required: true" : ""
      disabled_attr = nil
      restriction_label = nil
    end

    # Generate conditional attributes with initial visibility based on model value
    conditional_wrapper_start = ""
    conditional_wrapper_end = ""
    if field.conditional?
      conditional_field = field.conditional_field
      if conditional_field
        values_json = field.conditional_values.to_json.gsub('"', '&quot;')
        # For edit view, show conditional fields based on current model values
        conditional_wrapper_start = "          <div class=\"conditional-field\" data-depends-on=\"#{conditional_field.field_name}\" data-show-values=\"#{values_json}\" style=\"<%= #{field.conditional_values.inspect}.include?(@#{form_template.file_name}.#{conditional_field.field_name}) ? '' : 'display: none;' %>\">\n"
        conditional_wrapper_end = "          </div>\n"
        # For conditional fields, don't require them initially (JS will handle validation)
        required_logic = "" if field.required
      end
    end

    # Build attributes hash string
    attrs = ["class: \"form-control\""]
    attrs << required_logic if required_logic.present?
    attrs << disabled_attr if disabled_attr.present?
    # Add data attribute for dropdowns that have conditional dependencies
    if field.dropdown? && has_conditional_dependents?(field)
      attrs << "data: { conditional_trigger: '#{field.field_name}' }"
    end
    attrs_str = attrs.join(", ")

    case field.field_type
    when 'text'
      html = ""
      html += "        <% #{editable_check} %>\n" if editable_check
      html += conditional_wrapper_start
      html += <<~HTML
              <div class="form-group flex-fill<%= #{editable_check ? "' field-restricted' unless field_#{field.id}_editable" : "''"} %>">
                <%= form.label :#{field.field_name}, "#{field.label}" %>
      HTML
      html += "            <small class=\"restriction-notice\">#{restriction_label}</small>\n" if restriction_label
      html += "            <%= form.text_field :#{field.field_name}, #{attrs_str} %>\n"
      html += "          </div>\n"
      html += conditional_wrapper_end
      html
    when 'text_box'
      html = ""
      html += "        <% #{editable_check} %>\n" if editable_check
      html += conditional_wrapper_start
      html += <<~HTML
              <div class="form-group flex-fill<%= #{editable_check ? "' field-restricted' unless field_#{field.id}_editable" : "''"} %>">
                <%= form.label :#{field.field_name}, "#{field.label}" %>
      HTML
      html += "            <small class=\"restriction-notice\">#{restriction_label}</small>\n" if restriction_label
      html += "            <%= form.text_area :#{field.field_name}, rows: #{field.rows}, #{attrs_str} %>\n"
      html += "          </div>\n"
      html += conditional_wrapper_end
      html
    when 'dropdown'
      options = field.dropdown_values.map { |v| "'#{v}'" }.join(', ')
      html = ""
      html += "        <% #{editable_check} %>\n" if editable_check
      html += conditional_wrapper_start
      html += <<~HTML
              <div class="form-group flex-fill<%= #{editable_check ? "' field-restricted' unless field_#{field.id}_editable" : "''"} %>">
                <%= form.label :#{field.field_name}, "#{field.label}" %>
      HTML
      html += "            <small class=\"restriction-notice\">#{restriction_label}</small>\n" if restriction_label
      html += "            <%= form.select :#{field.field_name},\n"
      html += "                  options_for_select([#{options}], @#{form_template.file_name}.#{field.field_name}),\n"
      html += "                  { include_blank: \"Select...\" },\n"
      html += "                  { #{attrs_str} } %>\n"
      html += "          </div>\n"
      html += conditional_wrapper_end
      html
    when 'date'
      html = ""
      html += "        <% #{editable_check} %>\n" if editable_check
      html += conditional_wrapper_start
      html += <<~HTML
              <div class="form-group flex-fill<%= #{editable_check ? "' field-restricted' unless field_#{field.id}_editable" : "''"} %>">
                <%= form.label :#{field.field_name}, "#{field.label}" %>
      HTML
      html += "            <small class=\"restriction-notice\">#{restriction_label}</small>\n" if restriction_label
      html += "            <%= form.datetime_local_field :#{field.field_name}, #{attrs_str} %>\n"
      html += "          </div>\n"
      html += conditional_wrapper_end
      html
    end
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
    # Generate restriction check and attributes
    if field.restricted?
      editable_check = generate_editable_check(field)
      required_logic = field.required ? "required: field_#{field.id}_editable && #{field.required}" : ""
      disabled_attr = "disabled: !field_#{field.id}_editable"
      restriction_label = field.restriction_label
    else
      editable_check = nil
      required_logic = field.required ? "required: true" : ""
      disabled_attr = nil
      restriction_label = nil
    end

    # Generate conditional attributes
    conditional_wrapper_start = ""
    conditional_wrapper_end = ""
    if field.conditional?
      conditional_field = field.conditional_field
      if conditional_field
        values_json = field.conditional_values.to_json.gsub('"', '&quot;')
        conditional_wrapper_start = "          <div class=\"conditional-field\" data-depends-on=\"#{conditional_field.field_name}\" data-show-values=\"#{values_json}\" style=\"display: none;\">\n"
        conditional_wrapper_end = "          </div>\n"
        # For conditional fields, don't require them initially (JS will handle validation)
        required_logic = "" if field.required
      end
    end

    # Build attributes hash string
    attrs = ["class: \"form-control\""]
    attrs << required_logic if required_logic.present?
    attrs << disabled_attr if disabled_attr.present?
    # Add data attribute for dropdowns that have conditional dependencies
    if field.dropdown? && has_conditional_dependents?(field)
      attrs << "data: { conditional_trigger: '#{field.field_name}' }"
    end
    attrs_str = attrs.join(", ")

    case field.field_type
    when 'text'
      html = ""
      html += "        <% #{editable_check} %>\n" if editable_check
      html += conditional_wrapper_start
      html += <<~HTML
              <div class="form-group flex-fill<%= #{editable_check ? "' field-restricted' unless field_#{field.id}_editable" : "''"} %>">
                <%= form.label :#{field.field_name}, "#{field.label}" %>
      HTML
      html += "            <small class=\"restriction-notice\">#{restriction_label}</small>\n" if restriction_label
      html += "            <%= form.text_field :#{field.field_name}, #{attrs_str} %>\n"
      html += "          </div>\n"
      html += conditional_wrapper_end
      html
    when 'text_box'
      html = ""
      html += "        <% #{editable_check} %>\n" if editable_check
      html += conditional_wrapper_start
      html += <<~HTML
              <div class="form-group flex-fill<%= #{editable_check ? "' field-restricted' unless field_#{field.id}_editable" : "''"} %>">
                <%= form.label :#{field.field_name}, "#{field.label}" %>
      HTML
      html += "            <small class=\"restriction-notice\">#{restriction_label}</small>\n" if restriction_label
      html += "            <%= form.text_area :#{field.field_name}, rows: #{field.rows}, #{attrs_str} %>\n"
      html += "          </div>\n"
      html += conditional_wrapper_end
      html
    when 'dropdown'
      options = field.dropdown_values.map { |v| "'#{v}'" }.join(', ')
      html = ""
      html += "        <% #{editable_check} %>\n" if editable_check
      html += conditional_wrapper_start
      html += <<~HTML
              <div class="form-group flex-fill<%= #{editable_check ? "' field-restricted' unless field_#{field.id}_editable" : "''"} %>">
                <%= form.label :#{field.field_name}, "#{field.label}" %>
      HTML
      html += "            <small class=\"restriction-notice\">#{restriction_label}</small>\n" if restriction_label
      html += "            <%= form.select :#{field.field_name},\n"
      html += "                  options_for_select([#{options}]),\n"
      html += "                  { include_blank: \"Select...\" },\n"
      html += "                  { #{attrs_str} } %>\n"
      html += "          </div>\n"
      html += conditional_wrapper_end
      html
    when 'date'
      html = ""
      html += "        <% #{editable_check} %>\n" if editable_check
      html += conditional_wrapper_start
      html += <<~HTML
              <div class="form-group flex-fill<%= #{editable_check ? "' field-restricted' unless field_#{field.id}_editable" : "''"} %>">
                <%= form.label :#{field.field_name}, "#{field.label}" %>
      HTML
      html += "            <small class=\"restriction-notice\">#{restriction_label}</small>\n" if restriction_label
      html += "            <%= form.datetime_local_field :#{field.field_name}, #{attrs_str} %>\n"
      html += "          </div>\n"
      html += conditional_wrapper_end
      html
    end
  end

  def has_conditional_dependents?(field)
    field.form_template.form_fields.any? { |f| f.conditional_field_id == field.id }
  end

  def generate_editable_check(field)
    case field.restricted_to_type
    when 'employee'
      "field_#{field.id}_editable = (session.dig(:user, 'employee_id').to_s == '#{field.restricted_to_employee_id}')"
    when 'group'
      "field_#{field.id}_editable = @current_user_groups&.include?(#{field.restricted_to_group_id})"
    else
      nil
    end
  end
end
