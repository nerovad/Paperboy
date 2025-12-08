class FormTemplatesController < ApplicationController
  before_action :require_system_admin
  before_action :set_form_template, only: [:show, :destroy]
  
  def index
    @form_templates = FormTemplate.all.order(created_at: :desc)
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
    
    # Run the destroy command to remove generated files
    destroy_output = `cd #{Rails.root} && bin/rails destroy paperboy_form #{class_name} 2>&1`
    
    # Delete the template record
    if @form_template.destroy
      redirect_to form_templates_path, notice: "Form template and generated files deleted successfully."
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
    
    # First, remove the incorrectly placed line (generator puts it at the very end)
    sidebar_content = File.read(sidebar)
    incorrect_line = %(      ["#{label}", #{helper}],)
    sidebar_content.gsub!(/^\s*#{Regexp.escape(incorrect_line)}\s*\n/, '')
    File.write(sidebar, sidebar_content)
    
    if form_template.restricted?
      # Add to restricted_forms array with group requirement
      group_name = form_template.acl_group_name
      line = %(      ["#{label}", #{helper}, ["#{group_name}"]],\n)
      
      # Insert before the closing of restricted_forms (before "# Build available forms list")
      insert_into_file sidebar,
                      line,
                      before: /^\s*# Build available forms list/
    else
      # Add to public_forms array
      line = %(      ["#{label}", #{helper}],\n)
      
      # Insert before the closing of public_forms (before "# Restricted forms")
      insert_into_file sidebar,
                      line,
                      before: /^\s*# Restricted forms/
    end
  end  
  def form_template_params
    params.require(:form_template).permit(
      :name,
      :access_level,
      :acl_group_id,
      :page_count,
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
end
