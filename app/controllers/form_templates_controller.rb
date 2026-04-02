class FormTemplatesController < ApplicationController
  before_action :require_system_admin
  before_action :set_form_template, only: [:show, :edit, :update, :destroy]
  
  def index
    @form_templates = FormTemplate.includes(:form_fields).order(:name)
    @acl_groups = fetch_acl_groups
    @employees = fetch_employees
    @existing_tags = FormTemplate.all_tags
  end

  def new
    @form_template = FormTemplate.new
  end
  
  def create
    @form_template = FormTemplate.new(form_template_params)
    @form_template.created_by = session.dig(:user, "employee_id")

    # Set pending routing steps to pass validation (they'll be saved after the form_template)
    @form_template.pending_routing_steps = params[:routing_steps] if params[:routing_steps].present?

    if @form_template.save
      # Save routing steps
      save_routing_steps(@form_template)

      # Sync statuses (user-configured + auto-generated from routing steps)
      sync_statuses(@form_template)

      # Save fields (two-pass: create first, then link conditionals)
      if params[:fields].present?
        # First pass: create all fields, store conditional references
        created_fields = []
        conditional_refs = []
        conditional_answer_refs = []

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
            restricted_to_group_id: field_data[:restricted_to_group_id].presence,
            read_only: field_data[:read_only].presence || 'none'
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

          # Store conditional answer reference if present
          if field_data[:conditional_answer_field_id].present? && field_data[:conditional_answer_mappings].present?
            mappings = field_data[:conditional_answer_mappings].to_unsafe_h.reject { |_, v| v.blank? }
            if mappings.any?
              conditional_answer_refs << {
                field: field,
                ref: field_data[:conditional_answer_field_id],
                mappings: mappings
              }
            end
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

        # Resolve conditional answer field references to actual IDs
        conditional_answer_refs.each do |ref_data|
          if ref_data[:ref] =~ /^field_(\d+)$/
            ref_index = $1.to_i
            if created_fields[ref_index]
              ref_data[:field].update!(
                conditional_answer_field_id: created_fields[ref_index].id,
                conditional_answer_mappings: ref_data[:mappings]
              )
            end
          elsif ref_data[:ref].to_i > 0
            ref_data[:field].update!(
              conditional_answer_field_id: ref_data[:ref].to_i,
              conditional_answer_mappings: ref_data[:mappings]
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

        # Grant access: public forms go to everyone, restricted forms auto-grant to select-all scopes
        if @form_template.visibility == 'public'
          grant_to_all_scopes(@form_template)
        else
          auto_grant_to_select_all_scopes(@form_template)
        end

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
    @existing_tags = FormTemplate.all_tags
  end

  def update
    routing_changed = routing_fields_changed?
    fields_changed = form_fields_changed?
    statuses_changed = statuses_fields_changed?
    visibility_changed_to_public = @form_template.visibility != 'public' && form_template_params[:visibility] == 'public'

    # Set pending routing steps to pass validation (same as create)
    @form_template.pending_routing_steps = params[:routing_steps] if params[:routing_steps].present?

    if @form_template.update(form_template_params)
      # If visibility just changed to public, grant to all orgs and groups
      grant_to_all_scopes(@form_template) if visibility_changed_to_public
      # Only rebuild routing steps when routing actually changed
      if routing_changed
        rebuild_routing_steps(@form_template)
      end

      # Only sync statuses when statuses or routing changed
      if statuses_changed || routing_changed
        sync_statuses(@form_template)
      end

      # Only rebuild fields and regenerate views when fields actually changed
      if fields_changed
        rebuild_form_fields
        generate_dynamic_view(@form_template.class_name)
        generate_dynamic_edit_view(@form_template.class_name)
      end

      # Only regenerate model when statuses or routing changed (enum needs to match)
      if statuses_changed || routing_changed
        customize_generated_model(@form_template)
      end

      if routing_changed
        customize_generated_controller(@form_template)
        Rails.logger.info "Regenerated controller for #{@form_template.class_name}"
      end

      message = routing_changed ?
        "Form template updated successfully. Controller was regenerated." :
        "Form template updated successfully."

      respond_to do |format|
        format.json { render json: { success: true, message: message, redirect: form_template_path(@form_template) } }
        format.html { redirect_to form_template_path(@form_template), notice: message }
      end
    else
      respond_to do |format|
        format.json { render json: { success: false, errors: @form_template.errors.full_messages }, status: :unprocessable_entity }
        format.html do
          @acl_groups = fetch_acl_groups
          @employees = fetch_employees
          @fields_by_page = @form_template.form_fields.ordered.group_by(&:page_number)
          @agency_options = Agency.order(:long_name).pluck(:long_name, :agency_id) rescue []
          load_org_scope_chain
          render :edit, status: :unprocessable_entity
        end
      end
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

    label = form_template.name
    helper = "new_#{class_name.underscore}_path"

    # Read the sidebar content and clean up any lines the generator may have
    # incorrectly placed. FormTemplates are now loaded dynamically from the DB,
    # so they don't need to be hardcoded in the sidebar.
    sidebar_content = File.read(sidebar)

    incorrect_line = %(      ["#{label}", #{helper}],)
    if sidebar_content.gsub!(/^\s*#{Regexp.escape(incorrect_line)}\s*\n/, '')
      File.write(sidebar, sidebar_content)
    end
  end

  # When a new form is created, auto-grant it to any org scope or group
  # that currently has every existing form selected (i.e. Select All was on).
  def auto_grant_to_select_all_scopes(new_template)
    # Build the set of all form permission keys that existed BEFORE this template
    legacy_keys = AclController::LEGACY_FORMS.map { |f| f[:key] }
    template_names = FormTemplate.pluck(:name).map(&:downcase).to_set
    legacy_keys.reject! { |k| template_names.include?(AclController::LEGACY_FORMS.find { |f| f[:key] == k }&.dig(:label)&.downcase) }
    existing_keys = legacy_keys + FormTemplate.where.not(id: new_template.id).pluck(:id).map(&:to_s)
    expected_count = existing_keys.size
    new_key = new_template.id.to_s

    # Org permissions: find scopes that had all forms selected
    OrgPermission.where(permission_type: 'form')
                 .select(:agency_id, :division_id, :department_id, :unit_id)
                 .group(:agency_id, :division_id, :department_id, :unit_id)
                 .having("COUNT(*) = ?", expected_count)
                 .each do |scope|
      OrgPermission.find_or_create_by!(
        agency_id: scope.agency_id,
        division_id: scope.division_id,
        department_id: scope.department_id,
        unit_id: scope.unit_id,
        permission_type: 'form',
        permission_key: new_key
      )
    end

    # Group permissions: find groups that had all forms selected
    GroupPermission.where(permission_type: 'form')
                   .select(:group_id)
                   .group(:group_id)
                   .having("COUNT(*) = ?", expected_count)
                   .each do |gp|
      GroupPermission.find_or_create_by!(
        group_id: gp.group_id,
        permission_type: 'form',
        permission_key: new_key
      )
    end
  rescue => e
    Rails.logger.warn "Auto-grant failed for template #{new_template.id}: #{e.message}"
  end

  def grant_to_all_scopes(template)
    permission_key = template.id.to_s

    # Grant to every distinct org scope that has any permissions
    existing_scopes = OrgPermission
      .select(:agency_id, :division_id, :department_id, :unit_id)
      .distinct
      .map { |s| [s.agency_id, s.division_id, s.department_id, s.unit_id] }
      .to_set

    # Also ensure every agency has a grant (even if not yet in org_permissions)
    Agency.pluck(:agency_id).each do |aid|
      existing_scopes << [aid, nil, nil, nil]
    end

    existing_scopes.each do |agency_id, division_id, department_id, unit_id|
      OrgPermission.find_or_create_by!(
        agency_id: agency_id,
        division_id: division_id,
        department_id: department_id,
        unit_id: unit_id,
        permission_type: 'form',
        permission_key: permission_key
      )
    end

    # Grant to every group
    Group.pluck(:GroupID).each do |gid|
      GroupPermission.find_or_create_by!(
        group_id: gid,
        permission_type: 'form',
        permission_key: permission_key
      )
    end
  rescue => e
    Rails.logger.warn "Grant-to-all failed for template #{template.id}: #{e.message}"
  end

  def form_template_params
    params.require(:form_template).permit(
      :name,
      :visibility,
      :page_count,
      :submission_type,
      :approval_routing_to,
      :approval_employee_id,
      :has_dashboard,
      :powerbi_workspace_id,
      :powerbi_report_id,
      :status_transition_mode,
      :tags,
      page_headers: [],
      inbox_buttons: []
    )
  end
  
  def build_field_options(field_data)
    options = {}

    case field_data[:field_type]
    when 'text_box'
      options['rows'] = field_data[:rows].to_i if field_data[:rows].present?
    when 'dropdown', 'choices_dropdown'
      if field_data[:data_source].present?
        options['data_source'] = field_data[:data_source]
        options['data_source_column'] = field_data[:data_source_column]
        options['data_source_filter'] = field_data[:data_source_filter] if field_data[:data_source_filter].present?
      elsif field_data[:dropdown_values].present?
        options['values'] = field_data[:dropdown_values].split(',').map(&:strip)
      end
    end

    options
  end
  
  def fetch_acl_groups
    Group.order(:group_name).pluck(:group_name, :GroupID)
  rescue
    []
  end

  def fetch_employees
    Employee.order(:last_name, :first_name)
            .map { |e| ["#{e.first_name} #{e.last_name} (#{e.employee_id})", e.employee_id] }
  rescue
    []
  end

  def customize_generated_model(form_template)
    model_path = Rails.root.join("app/models/#{form_template.file_name}.rb")
    return unless File.exist?(model_path)

    content = File.read(model_path)

    if form_template.submission_type == 'database' && form_template.statuses.empty?
      # No statuses configured for database-only form — remove enum block
      content.gsub!(/^\s*enum :status.*?\n\s*\}/m, '')
      content.gsub!(/^\s*STATUS_CATEGORIES\s*=\s*\{.*?\}\.freeze/m, '')
      content.gsub!(/^\s*STATUS_LABELS\s*=\s*\{.*?\}\.freeze/m, '')
    else
      # Generate unified enum from all statuses (user + auto-generated)
      generate_unified_status_enum(form_template, content)
    end

    # Update status_label method to use STATUS_LABELS
    status_label_code = <<~RUBY.chomp
      def status_label
        self.class.const_defined?(:STATUS_LABELS) ? (self.class::STATUS_LABELS[status&.to_sym] || status&.to_s&.humanize || "Unknown") : (status&.to_s&.humanize || "Unknown")
      end
    RUBY

    if content =~ /def status_label\n.*?\n  end/m
      content.gsub!(/def status_label\n.*?\n  end/m, status_label_code)
    end

    File.write(model_path, content)
  end

  def generate_unified_status_enum(form_template, content)
    all_statuses = form_template.statuses.ordered.to_a
    return if all_statuses.empty?

    # Find the initial status
    initial_status = all_statuses.find(&:is_initial) || all_statuses.first
    default_key = initial_status.key

    # Build enum entries
    enum_entries = all_statuses.each_with_index.map do |status, index|
      "#{status.key}: #{index}"
    end

    # Build STATUS_CATEGORIES
    category_entries = all_statuses.map do |status|
      "#{status.key}: :#{status.category}"
    end

    # Build STATUS_LABELS
    label_entries = all_statuses.map do |status|
      "#{status.key}: \"#{status.name}\""
    end

    new_block = <<~RUBY.chomp
      enum :status, {
        #{enum_entries.join(",\n    ")}
      }, default: :#{default_key}

      # Normalized status categories for cross-form reporting
      STATUS_CATEGORIES = {
        #{category_entries.join(",\n    ")}
      }.freeze

      # Human-readable status labels
      STATUS_LABELS = {
        #{label_entries.join(",\n    ")}
      }.freeze
    RUBY

    # Remove existing blocks first, then insert the new unified block
    # Remove enum block
    content.gsub!(/^\s*enum :status.*?\n\s*\}(,\s*default:\s*:\w+)?/m, '')
    # Remove existing STATUS_CATEGORIES
    content.gsub!(/^\s*#[^\n]*status categories[^\n]*\n\s*STATUS_CATEGORIES\s*=\s*\{.*?\}\.freeze/m, '')
    # Remove existing STATUS_LABELS
    content.gsub!(/^\s*#[^\n]*status labels[^\n]*\n\s*STATUS_LABELS\s*=\s*\{.*?\}\.freeze/m, '')
    # Also remove standalone constants without comments
    content.gsub!(/^\s*STATUS_CATEGORIES\s*=\s*\{.*?\}\.freeze/m, '')
    content.gsub!(/^\s*STATUS_LABELS\s*=\s*\{.*?\}\.freeze/m, '')

    # Clean up blank lines left behind
    content.gsub!(/\n{3,}/, "\n\n")

    # Insert after `include TrackableStatus`
    content.sub!(/include TrackableStatus\n/) do |match|
      "#{match}\n#{new_block}\n"
    end
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
      { routing_type: step.routing_type, employee_id: step.employee_id, display_name: step.display_name }
    end

    new_steps = (params[:routing_steps] || []).map do |step|
      { routing_type: step[:routing_type], employee_id: step[:employee_id]&.to_i.presence, display_name: step[:display_name].presence }
    end.reject { |s| s[:routing_type].blank? }

    current_steps != new_steps
  end

  def form_fields_changed?
    return false unless @form_template

    current_fields = @form_template.form_fields.ordered.map do |f|
      { label: f.label, field_type: f.field_type, page_number: f.page_number, required: f.required, read_only: f.read_only || 'none', options: f.options }
    end

    new_fields = (params[:fields] || []).map do |f|
      {
        label: f[:label],
        field_type: f[:field_type],
        page_number: f[:page_number].to_i,
        required: f[:required] == '1',
        read_only: f[:read_only].presence || 'none',
        options: case f[:field_type]
                 when 'text_box' then { 'rows' => f[:rows].to_i }
                 when 'dropdown', 'choices_dropdown'
                   if f[:data_source].present?
                     opts = { 'data_source' => f[:data_source], 'data_source_column' => f[:data_source_column] }
                     opts['data_source_filter'] = f[:data_source_filter] if f[:data_source_filter].present?
                     opts
                   elsif f[:dropdown_values].present?
                     { 'values' => f[:dropdown_values].split(',').map(&:strip) }
                   else
                     {}
                   end
                 else {}
                 end
      }
    end.reject { |f| f[:label].blank? }

    current_fields != new_fields
  end

  def statuses_fields_changed?
    return false unless @form_template

    current_statuses = @form_template.statuses.user_configured.ordered.map do |s|
      { name: s.name, key: s.key, category: s.category, is_initial: s.is_initial, is_end: s.is_end }
    end

    new_statuses = (params[:statuses] || []).map do |s|
      next nil if s[:name].blank? || s[:category].blank?
      {
        name: s[:name],
        key: s[:key].presence || s[:name].parameterize.underscore,
        category: s[:category],
        is_initial: s[:is_initial] == '1',
        is_end: s[:is_end] == '1'
      }
    end.compact

    current_statuses != new_statuses
  end

  def save_routing_steps(form_template)
    return unless params[:routing_steps].present?

    params[:routing_steps].each do |step_data|
      next if step_data[:routing_type].blank?

      form_template.routing_steps.create!(
        step_number: step_data[:step_number].to_i,
        routing_type: step_data[:routing_type],
        employee_id: step_data[:employee_id].presence,
        display_name: step_data[:display_name].presence
      )
    end
  end

  def sync_statuses(form_template)
    # Destroy auto-generated statuses (they'll be recreated)
    form_template.statuses.auto_generated.destroy_all
    # Destroy user-configured statuses (they'll be recreated from params)
    form_template.statuses.user_configured.destroy_all

    position = 0

    # 1. Save user-submitted statuses from params (initial/non-end statuses first)
    if params[:statuses].present?
      initial_statuses = []
      terminal_statuses = []

      params[:statuses].each_with_index do |status_data, index|
        next if status_data[:name].blank? || status_data[:category].blank?

        data = {
          name: status_data[:name],
          key: status_data[:key].presence || status_data[:name].parameterize.underscore,
          category: status_data[:category],
          is_initial: status_data[:is_initial] == '1',
          is_end: status_data[:is_end] == '1',
          auto_generated: false
        }

        if data[:is_end]
          terminal_statuses << data
        else
          initial_statuses << data
        end
      end

      # Create initial/non-end user statuses first
      initial_statuses.each do |data|
        form_template.statuses.create!(data.merge(position: position))
        position += 1
      end

      # 2. Auto-generate step statuses from routing steps
      if form_template.requires_approval? && form_template.routing_steps.any?
        steps = form_template.routing_steps.ordered.to_a

        steps.each_with_index do |step, index|
          step_num = index + 1

          # Create step_N_pending
          form_template.statuses.create!(
            name: step.pending_display_name,
            key: "step_#{step_num}_pending",
            category: 'in_review',
            position: position,
            is_initial: false,
            is_end: false,
            auto_generated: true
          )
          position += 1

          # Create step_N_approved for non-final steps
          unless step_num == steps.count
            form_template.statuses.create!(
              name: step.approved_display_name,
              key: "step_#{step_num}_approved",
              category: 'in_review',
              position: position,
              is_initial: false,
              is_end: false,
              auto_generated: true
            )
            position += 1
          end
        end
      end

      # Create terminal user statuses last
      terminal_statuses.each do |data|
        form_template.statuses.create!(data.merge(position: position))
        position += 1
      end
    elsif form_template.requires_approval? && form_template.routing_steps.any?
      # No user statuses but has routing steps — create a default set
      steps = form_template.routing_steps.ordered.to_a

      # Default initial status
      form_template.statuses.create!(
        name: 'Submitted', key: 'submitted', category: 'pending',
        position: position, is_initial: true, is_end: false, auto_generated: false
      )
      position += 1

      # Auto-generate step statuses
      steps.each_with_index do |step, index|
        step_num = index + 1

        form_template.statuses.create!(
          name: step.pending_display_name,
          key: "step_#{step_num}_pending",
          category: 'in_review',
          position: position,
          is_initial: false, is_end: false, auto_generated: true
        )
        position += 1

        unless step_num == steps.count
          form_template.statuses.create!(
            name: step.approved_display_name,
            key: "step_#{step_num}_approved",
            category: 'in_review',
            position: position,
            is_initial: false, is_end: false, auto_generated: true
          )
          position += 1
        end
      end

      # Default terminal statuses
      form_template.statuses.create!(
        name: 'Approved', key: 'approved', category: 'approved',
        position: position, is_initial: false, is_end: true, auto_generated: false
      )
      position += 1
      form_template.statuses.create!(
        name: 'Denied', key: 'denied', category: 'denied',
        position: position, is_initial: false, is_end: true, auto_generated: false
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
        employee_id: step_data[:employee_id].presence,
        display_name: step_data[:display_name].presence
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
      conditional_answer_refs = []

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
          restricted_to_group_id: field_data[:restricted_to_group_id].presence,
          read_only: field_data[:read_only].presence || 'none'
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

        # Store conditional answer reference if present
        if field_data[:conditional_answer_field_id].present? && field_data[:conditional_answer_mappings].present?
          mappings = field_data[:conditional_answer_mappings].to_unsafe_h.reject { |_, v| v.blank? }
          if mappings.any?
            conditional_answer_refs << {
              field: field,
              ref: field_data[:conditional_answer_field_id],
              mappings: mappings
            }
          end
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

      # Resolve conditional answer field references to actual IDs
      conditional_answer_refs.each do |ref_data|
        if ref_data[:ref] =~ /^field_(\d+)$/
          ref_index = $1.to_i
          if created_fields[ref_index]
            ref_data[:field].update!(
              conditional_answer_field_id: created_fields[ref_index].id,
              conditional_answer_mappings: ref_data[:mappings]
            )
          end
        elsif ref_data[:ref].to_i > 0
          ref_data[:field].update!(
            conditional_answer_field_id: ref_data[:ref].to_i,
            conditional_answer_mappings: ref_data[:mappings]
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
        employee = Employee.find_by(employee_id: session.dig(:user, "employee_id"))
        approver_id = employee&.supervisor_id&.to_s
      RUBY
    when 'department_head'
      <<~RUBY.chomp
        # Look up the submitter's department head
        employee = Employee.find_by(employee_id: session.dig(:user, "employee_id"))
        unit = employee ? Unit.find_by(unit_id: employee.unit) : nil
        department = unit ? Department.find_by(department_id: unit.department_id) : nil
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
    controllers << "conditional-fields" if form_template.form_fields.conditional.any? || form_template.form_fields.any?(&:conditional_answer?)
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
    controllers << "conditional-fields" if form_template.form_fields.conditional.any? || form_template.form_fields.any?(&:conditional_answer?)
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

    # Read-only handling: on edit view, only 'always' is readonly ('initial' becomes editable)
    is_read_only = field.read_only_always?
    readonly_attr = is_read_only ? "readonly: true" : nil

    # Generate conditional answer data attributes for the form-group div
    conditional_answer_attrs = ""
    if field.conditional_answer?
      answer_field = field.conditional_answer_field
      if answer_field
        mappings_json = field.conditional_answer_mappings.to_json.gsub('"', '&quot;')
        conditional_answer_attrs = " data-answer-depends-on=\"#{answer_field.field_name}\" data-answer-mappings=\"#{mappings_json}\""
      end
    end

    # Build attributes hash string
    attrs = ["class: \"form-control#{ is_read_only ? ' field-readonly' : '' }\""]
    attrs << required_logic if required_logic.present?
    attrs << disabled_attr if disabled_attr.present?
    attrs << readonly_attr if readonly_attr.present?
    # Add data attribute for dropdowns that have conditional dependencies
    if (field.dropdown? || field.choices_dropdown?) && has_conditional_dependents?(field)
      attrs << "data: { conditional_trigger: '#{field.field_name}' }"
    end
    attrs_str = attrs.join(", ")

    # For select/dropdown fields, use disabled instead of readonly (readonly doesn't work on selects)
    select_attrs = attrs.reject { |a| a == "readonly: true" }
    select_attrs << "disabled: true" if is_read_only && disabled_attr.nil?
    select_attrs_str = select_attrs.join(", ")

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
      has_agency_filter = field.data_source? && field.options&.dig('data_source_filter') == 'agency'
      if has_agency_filter
        col = field.data_source_column || 'full_name'
        record_var = "@#{form_template.file_name}"
        div_data = "data-controller=\"dependent-select\" data-dependent-select-url-value=\"/lookups/employees\" data-dependent-select-param-value=\"agency\" data-dependent-select-column-value=\"#{col}\" data-dependent-select-source-selector-value=\"#agency-select\""
        html = ""
        html += "        <% #{editable_check} %>\n" if editable_check
        html += conditional_wrapper_start
        html += "          <div class=\"form-group flex-fill<%= #{editable_check ? "' field-restricted' unless field_#{field.id}_editable" : "''"} %>\" #{div_data}#{conditional_answer_attrs}>\n"
        html += "            <%= form.label :#{field.field_name}, \"#{field.label}\" %>\n"
        html += "            <small class=\"restriction-notice\">#{restriction_label}</small>\n" if restriction_label
          html += "            <%= form.select :#{field.field_name},\n"
        html += "                  options_for_select(#{record_var}.agency.present? ? Employee.where(Agency: #{record_var}.agency).order(:Last_Name).map { |e| \"\#{e.last_name}, \#{e.first_name}\" } : [], #{record_var}.#{field.field_name}),\n"
        html += "                  { include_blank: \"Select agency first...\" },\n"
        html += "                  { #{select_attrs_str}, data: { dependent_select_target: \"select\" } } %>\n"
        html += "          </div>\n"
        html += conditional_wrapper_end
        html
      else
        if field.data_source?
          options_expr = field.data_source_query_code
          selected_expr = "@#{form_template.file_name}.#{field.field_name}"
        else
          options = field.dropdown_values.map { |v| "'#{v}'" }.join(', ')
          options_expr = "[#{options}]"
          selected_expr = "@#{form_template.file_name}.#{field.field_name}"
        end
        html = ""
        html += "        <% #{editable_check} %>\n" if editable_check
        html += conditional_wrapper_start
        html += <<~HTML
                <div class="form-group flex-fill<%= #{editable_check ? "' field-restricted' unless field_#{field.id}_editable" : "''"} %>"#{conditional_answer_attrs}>
                  <%= form.label :#{field.field_name}, "#{field.label}" %>
        HTML
        html += "            <small class=\"restriction-notice\">#{restriction_label}</small>\n" if restriction_label
          html += "            <%= form.select :#{field.field_name},\n"
        html += "                  options_for_select(#{options_expr}, #{selected_expr}),\n"
        html += "                  { include_blank: \"Select...\" },\n"
        html += "                  { #{select_attrs_str} } %>\n"
        html += "          </div>\n"
        html += conditional_wrapper_end
        html
      end
    when 'choices_dropdown'
      has_agency_filter = field.data_source? && field.options&.dig('data_source_filter') == 'agency'
      if has_agency_filter
        col = field.data_source_column || 'full_name'
        record_var = "@#{form_template.file_name}"
        div_data = "data-controller=\"dependent-select choices\" data-dependent-select-url-value=\"/lookups/employees\" data-dependent-select-param-value=\"agency\" data-dependent-select-column-value=\"#{col}\" data-dependent-select-source-selector-value=\"#agency-select\""
        html = ""
        html += "        <% #{editable_check} %>\n" if editable_check
        html += conditional_wrapper_start
        html += "          <div class=\"form-group flex-fill<%= #{editable_check ? "' field-restricted' unless field_#{field.id}_editable" : "''"} %>\" #{div_data}#{conditional_answer_attrs}>\n"
        html += "            <%= form.label :#{field.field_name}, \"#{field.label}\" %>\n"
        html += "            <small class=\"restriction-notice\">#{restriction_label}</small>\n" if restriction_label
          html += "            <%= form.select :#{field.field_name},\n"
        html += "                  options_for_select([]),\n"
        html += "                  { include_blank: false },\n"
        html += "                  { #{select_attrs_str}, multiple: true, data: { dependent_select_target: \"select\", choices_target: \"select\", placeholder: \"Select agency first...\" } } %>\n"
        html += "          </div>\n"
        html += conditional_wrapper_end
        html
      else
        if field.data_source?
          options_expr = field.data_source_query_code
        else
          options = field.dropdown_values.map { |v| "'#{v}'" }.join(', ')
          options_expr = "[#{options}]"
        end
        html = ""
        html += "        <% #{editable_check} %>\n" if editable_check
        html += conditional_wrapper_start
        html += <<~HTML
                <div class="form-group flex-fill<%= #{editable_check ? "' field-restricted' unless field_#{field.id}_editable" : "''"} %>"#{conditional_answer_attrs} data-controller="choices">
                  <%= form.label :#{field.field_name}, "#{field.label}" %>
        HTML
        html += "            <small class=\"restriction-notice\">#{restriction_label}</small>\n" if restriction_label
          html += "            <%= form.select :#{field.field_name},\n"
        html += "                  options_for_select(#{options_expr}),\n"
        html += "                  { include_blank: false },\n"
        html += "                  { #{select_attrs_str}, multiple: true, data: { choices_target: \"select\", placeholder: \"Select options...\" } } %>\n"
        html += "          </div>\n"
        html += conditional_wrapper_end
        html
      end
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
    when 'phone'
      phone_id = field.field_name.camelize(:lower)
      phone_attrs = ["class: \"form-control#{ is_read_only ? ' field-readonly' : '' }\""]
      phone_attrs << required_logic if required_logic.present?
      phone_attrs << disabled_attr if disabled_attr.present?
      phone_attrs << readonly_attr if readonly_attr.present?
      phone_attrs << "placeholder: \"e.g. 555-555-5555\""
      phone_attrs << "title: \"Enter a 10-digit phone number like 555-555-5555\""
      phone_attrs << "data: { controller: \"phone\", phone_target: \"input\", action: \"input->phone#format paste->phone#format blur->phone#validate\" }"
      phone_attrs << "\"aria-describedby\": \"#{phone_id}Help #{phone_id}Error\""
      phone_attrs << "pattern: \"\\\\d{3}-\\\\d{3}-\\\\d{4}\""
      phone_attrs << "inputmode: \"numeric\""
      phone_attrs << "autocomplete: \"tel\""
      phone_attrs_str = phone_attrs.join(",\n                  ")
      html = ""
      html += "        <% #{editable_check} %>\n" if editable_check
      html += conditional_wrapper_start
      html += <<~HTML
              <div class="form-group flex-fill<%= #{editable_check ? "' field-restricted' unless field_#{field.id}_editable" : "''"} %>">
                <%= form.label :#{field.field_name}, "#{field.label}" %>
      HTML
      html += "            <small class=\"restriction-notice\">#{restriction_label}</small>\n" if restriction_label
      html += "            <%= form.text_field :#{field.field_name},\n"
      html += "                  #{phone_attrs_str} %>\n"
      html += "            <small id=\"#{phone_id}Help\" class=\"help-text text-muted\"></small>\n"
      html += "            <div id=\"#{phone_id}Error\" data-phone-target=\"error\" class=\"field-error\" aria-live=\"polite\"></div>\n"
      html += "          </div>\n"
      html += conditional_wrapper_end
      html
    when 'email'
      email_attrs = ["class: \"form-control#{ is_read_only ? ' field-readonly' : '' }\""]
      email_attrs << required_logic if required_logic.present?
      email_attrs << disabled_attr if disabled_attr.present?
      email_attrs << readonly_attr if readonly_attr.present?
      email_attrs << "placeholder: \"e.g. name@example.com\""
      email_attrs << "autocomplete: \"email\""
      email_attrs_str = email_attrs.join(", ")
      html = ""
      html += "        <% #{editable_check} %>\n" if editable_check
      html += conditional_wrapper_start
      html += <<~HTML
              <div class="form-group flex-fill<%= #{editable_check ? "' field-restricted' unless field_#{field.id}_editable" : "''"} %>">
                <%= form.label :#{field.field_name}, "#{field.label}" %>
      HTML
      html += "            <small class=\"restriction-notice\">#{restriction_label}</small>\n" if restriction_label
      html += "            <%= form.email_field :#{field.field_name}, #{email_attrs_str} %>\n"
      html += "          </div>\n"
      html += conditional_wrapper_end
      html
    when 'number'
      html = ""
      html += "        <% #{editable_check} %>\n" if editable_check
      html += conditional_wrapper_start
      html += <<~HTML
              <div class="form-group flex-fill<%= #{editable_check ? "' field-restricted' unless field_#{field.id}_editable" : "''"} %>">
                <%= form.label :#{field.field_name}, "#{field.label}" %>
      HTML
      html += "            <small class=\"restriction-notice\">#{restriction_label}</small>\n" if restriction_label
      html += "            <%= form.number_field :#{field.field_name}, #{attrs_str} %>\n"
      html += "          </div>\n"
      html += conditional_wrapper_end
      html
    when 'yes_no'
      html = ""
      html += "        <% #{editable_check} %>\n" if editable_check
      html += conditional_wrapper_start
      html += <<~HTML
              <div class="form-group flex-fill<%= #{editable_check ? "' field-restricted' unless field_#{field.id}_editable" : "''"} %>">
                <%= form.label :#{field.field_name}, "#{field.label}" %>
      HTML
      html += "            <small class=\"restriction-notice\">#{restriction_label}</small>\n" if restriction_label
      html += "            <%= form.select :#{field.field_name},\n"
      html += "                  options_for_select(['Yes', 'No'], @#{form_template.file_name}.#{field.field_name}),\n"
      html += "                  { include_blank: \"Select...\" },\n"
      html += "                  { #{select_attrs_str} } %>\n"
      html += "          </div>\n"
      html += conditional_wrapper_end
      html
    when 'time'
      html = ""
      html += "        <% #{editable_check} %>\n" if editable_check
      html += conditional_wrapper_start
      html += <<~HTML
              <div class="form-group flex-fill<%= #{editable_check ? "' field-restricted' unless field_#{field.id}_editable" : "''"} %>">
                <%= form.label :#{field.field_name}, "#{field.label}" %>
      HTML
      html += "            <small class=\"restriction-notice\">#{restriction_label}</small>\n" if restriction_label
      html += "            <%= form.time_field :#{field.field_name}, #{attrs_str} %>\n"
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

    # Read-only handling: on the new view, both 'always' and 'initial' are readonly
    is_read_only = field.read_only_always? || field.read_only_initial?
    readonly_attr = is_read_only ? "readonly: true" : nil

    # Generate conditional answer data attributes for the form-group div
    conditional_answer_attrs = ""
    if field.conditional_answer?
      answer_field = field.conditional_answer_field
      if answer_field
        mappings_json = field.conditional_answer_mappings.to_json.gsub('"', '&quot;')
        conditional_answer_attrs = " data-answer-depends-on=\"#{answer_field.field_name}\" data-answer-mappings=\"#{mappings_json}\""
      end
    end

    # Build attributes hash string
    attrs = ["class: \"form-control#{ is_read_only ? ' field-readonly' : '' }\""]
    attrs << required_logic if required_logic.present?
    attrs << disabled_attr if disabled_attr.present?
    attrs << readonly_attr if readonly_attr.present?
    # Add data attribute for dropdowns that have conditional dependencies
    if (field.dropdown? || field.choices_dropdown?) && has_conditional_dependents?(field)
      attrs << "data: { conditional_trigger: '#{field.field_name}' }"
    end
    attrs_str = attrs.join(", ")

    # For select/dropdown fields, use disabled instead of readonly (readonly doesn't work on selects)
    select_attrs = attrs.reject { |a| a == "readonly: true" }
    select_attrs << "disabled: true" if is_read_only && disabled_attr.nil?
    select_attrs_str = select_attrs.join(", ")

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
      has_agency_filter = field.data_source? && field.options&.dig('data_source_filter') == 'agency'
      if has_agency_filter
        # Cascading: options loaded dynamically via dependent-select controller
        col = field.data_source_column || 'full_name'
        div_data = "data-controller=\"dependent-select\" data-dependent-select-url-value=\"/lookups/employees\" data-dependent-select-param-value=\"agency\" data-dependent-select-column-value=\"#{col}\" data-dependent-select-source-selector-value=\"#agency-select\""
        html = ""
        html += "        <% #{editable_check} %>\n" if editable_check
        html += conditional_wrapper_start
        html += "          <div class=\"form-group flex-fill<%= #{editable_check ? "' field-restricted' unless field_#{field.id}_editable" : "''"} %>\" #{div_data}#{conditional_answer_attrs}>\n"
        html += "            <%= form.label :#{field.field_name}, \"#{field.label}\" %>\n"
        html += "            <small class=\"restriction-notice\">#{restriction_label}</small>\n" if restriction_label
          html += "            <%= form.select :#{field.field_name},\n"
        html += "                  options_for_select([]),\n"
        html += "                  { include_blank: \"Select agency first...\" },\n"
        html += "                  { #{select_attrs_str}, data: { dependent_select_target: \"select\" } } %>\n"
        html += "          </div>\n"
        html += conditional_wrapper_end
        html
      else
        if field.data_source?
          options_expr = field.data_source_query_code
        else
          options = field.dropdown_values.map { |v| "'#{v}'" }.join(', ')
          options_expr = "[#{options}]"
        end
        html = ""
        html += "        <% #{editable_check} %>\n" if editable_check
        html += conditional_wrapper_start
        html += <<~HTML
                <div class="form-group flex-fill<%= #{editable_check ? "' field-restricted' unless field_#{field.id}_editable" : "''"} %>"#{conditional_answer_attrs}>
                  <%= form.label :#{field.field_name}, "#{field.label}" %>
        HTML
        html += "            <small class=\"restriction-notice\">#{restriction_label}</small>\n" if restriction_label
          html += "            <%= form.select :#{field.field_name},\n"
        html += "                  options_for_select(#{options_expr}),\n"
        html += "                  { include_blank: \"Select...\" },\n"
        html += "                  { #{select_attrs_str} } %>\n"
        html += "          </div>\n"
        html += conditional_wrapper_end
        html
      end
    when 'choices_dropdown'
      has_agency_filter = field.data_source? && field.options&.dig('data_source_filter') == 'agency'
      if has_agency_filter
        col = field.data_source_column || 'full_name'
        div_data = "data-controller=\"dependent-select choices\" data-dependent-select-url-value=\"/lookups/employees\" data-dependent-select-param-value=\"agency\" data-dependent-select-column-value=\"#{col}\" data-dependent-select-source-selector-value=\"#agency-select\""
        html = ""
        html += "        <% #{editable_check} %>\n" if editable_check
        html += conditional_wrapper_start
        html += "          <div class=\"form-group flex-fill<%= #{editable_check ? "' field-restricted' unless field_#{field.id}_editable" : "''"} %>\" #{div_data}>\n"
        html += "            <%= form.label :#{field.field_name}, \"#{field.label}\" %>\n"
        html += "            <small class=\"restriction-notice\">#{restriction_label}</small>\n" if restriction_label
          html += "            <%= form.select :#{field.field_name},\n"
        html += "                  options_for_select([]),\n"
        html += "                  { include_blank: false },\n"
        html += "                  { #{select_attrs_str}, multiple: true, data: { dependent_select_target: \"select\", choices_target: \"select\", placeholder: \"Select agency first...\" } } %>\n"
        html += "          </div>\n"
        html += conditional_wrapper_end
        html
      else
        if field.data_source?
          options_expr = field.data_source_query_code
        else
          options = field.dropdown_values.map { |v| "'#{v}'" }.join(', ')
          options_expr = "[#{options}]"
        end
        html = ""
        html += "        <% #{editable_check} %>\n" if editable_check
        html += conditional_wrapper_start
        html += <<~HTML
                <div class="form-group flex-fill<%= #{editable_check ? "' field-restricted' unless field_#{field.id}_editable" : "''"} %>" data-controller="choices">
                  <%= form.label :#{field.field_name}, "#{field.label}" %>
        HTML
        html += "            <small class=\"restriction-notice\">#{restriction_label}</small>\n" if restriction_label
          html += "            <%= form.select :#{field.field_name},\n"
        html += "                  options_for_select(#{options_expr}),\n"
        html += "                  { include_blank: false },\n"
        html += "                  { #{select_attrs_str}, multiple: true, data: { choices_target: \"select\", placeholder: \"Select options...\" } } %>\n"
        html += "          </div>\n"
        html += conditional_wrapper_end
        html
      end
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
    when 'phone'
      phone_id = field.field_name.camelize(:lower)
      # Build phone attrs separately since we need data hash
      phone_attrs = ["class: \"form-control#{ is_read_only ? ' field-readonly' : '' }\""]
      phone_attrs << required_logic if required_logic.present?
      phone_attrs << disabled_attr if disabled_attr.present?
      phone_attrs << readonly_attr if readonly_attr.present?
      phone_attrs << "placeholder: \"e.g. 555-555-5555\""
      phone_attrs << "title: \"Enter a 10-digit phone number like 555-555-5555\""
      phone_attrs << "data: { controller: \"phone\", phone_target: \"input\", action: \"input->phone#format paste->phone#format blur->phone#validate\" }"
      phone_attrs << "\"aria-describedby\": \"#{phone_id}Help #{phone_id}Error\""
      phone_attrs << "pattern: \"\\\\d{3}-\\\\d{3}-\\\\d{4}\""
      phone_attrs << "inputmode: \"numeric\""
      phone_attrs << "autocomplete: \"tel\""
      phone_attrs_str = phone_attrs.join(",\n                  ")
      html = ""
      html += "        <% #{editable_check} %>\n" if editable_check
      html += conditional_wrapper_start
      html += <<~HTML
              <div class="form-group flex-fill<%= #{editable_check ? "' field-restricted' unless field_#{field.id}_editable" : "''"} %>">
                <%= form.label :#{field.field_name}, "#{field.label}" %>
      HTML
      html += "            <small class=\"restriction-notice\">#{restriction_label}</small>\n" if restriction_label
      html += "            <%= form.text_field :#{field.field_name},\n"
      html += "                  #{phone_attrs_str} %>\n"
      html += "            <small id=\"#{phone_id}Help\" class=\"help-text text-muted\"></small>\n"
      html += "            <div id=\"#{phone_id}Error\" data-phone-target=\"error\" class=\"field-error\" aria-live=\"polite\"></div>\n"
      html += "          </div>\n"
      html += conditional_wrapper_end
      html
    when 'email'
      email_attrs = ["class: \"form-control#{ is_read_only ? ' field-readonly' : '' }\""]
      email_attrs << required_logic if required_logic.present?
      email_attrs << disabled_attr if disabled_attr.present?
      email_attrs << readonly_attr if readonly_attr.present?
      email_attrs << "placeholder: \"e.g. name@example.com\""
      email_attrs << "autocomplete: \"email\""
      email_attrs_str = email_attrs.join(", ")
      html = ""
      html += "        <% #{editable_check} %>\n" if editable_check
      html += conditional_wrapper_start
      html += <<~HTML
              <div class="form-group flex-fill<%= #{editable_check ? "' field-restricted' unless field_#{field.id}_editable" : "''"} %>">
                <%= form.label :#{field.field_name}, "#{field.label}" %>
      HTML
      html += "            <small class=\"restriction-notice\">#{restriction_label}</small>\n" if restriction_label
      html += "            <%= form.email_field :#{field.field_name}, #{email_attrs_str} %>\n"
      html += "          </div>\n"
      html += conditional_wrapper_end
      html
    when 'number'
      html = ""
      html += "        <% #{editable_check} %>\n" if editable_check
      html += conditional_wrapper_start
      html += <<~HTML
              <div class="form-group flex-fill<%= #{editable_check ? "' field-restricted' unless field_#{field.id}_editable" : "''"} %>">
                <%= form.label :#{field.field_name}, "#{field.label}" %>
      HTML
      html += "            <small class=\"restriction-notice\">#{restriction_label}</small>\n" if restriction_label
      html += "            <%= form.number_field :#{field.field_name}, #{attrs_str} %>\n"
      html += "          </div>\n"
      html += conditional_wrapper_end
      html
    when 'yes_no'
      html = ""
      html += "        <% #{editable_check} %>\n" if editable_check
      html += conditional_wrapper_start
      html += <<~HTML
              <div class="form-group flex-fill<%= #{editable_check ? "' field-restricted' unless field_#{field.id}_editable" : "''"} %>">
                <%= form.label :#{field.field_name}, "#{field.label}" %>
      HTML
      html += "            <small class=\"restriction-notice\">#{restriction_label}</small>\n" if restriction_label
      html += "            <%= form.select :#{field.field_name},\n"
      html += "                  options_for_select(['Yes', 'No']),\n"
      html += "                  { include_blank: \"Select...\" },\n"
      html += "                  { #{select_attrs_str} } %>\n"
      html += "          </div>\n"
      html += conditional_wrapper_end
      html
    when 'time'
      html = ""
      html += "        <% #{editable_check} %>\n" if editable_check
      html += conditional_wrapper_start
      html += <<~HTML
              <div class="form-group flex-fill<%= #{editable_check ? "' field-restricted' unless field_#{field.id}_editable" : "''"} %>">
                <%= form.label :#{field.field_name}, "#{field.label}" %>
      HTML
      html += "            <small class=\"restriction-notice\">#{restriction_label}</small>\n" if restriction_label
      html += "            <%= form.time_field :#{field.field_name}, #{attrs_str} %>\n"
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
