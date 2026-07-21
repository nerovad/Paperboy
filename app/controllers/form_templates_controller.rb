# frozen_string_literal: true

require 'open3'

class FormTemplatesController < ApplicationController
  before_action -> { require_admin_tab('manage_forms') }
  before_action :set_form_template, only: %i[show edit update destroy archive unarchive]

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
    @form_template.created_by = session.dig(:user, 'employee_id')

    # Set pending routing steps to pass validation (they'll be saved after the form_template)
    @form_template.pending_routing_steps = params[:routing_steps] if params[:routing_steps].present?

    if @form_template.save
      # Save routing steps
      save_routing_steps(@form_template)

      # Save copy recipients
      save_copy_recipients(@form_template)

      # Save workflow email steps
      save_email_steps(@form_template)

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
            restricted_to_org_filter_level: (field_data[:restricted_to_type] == 'group' ? field_data[:restricted_to_org_filter_level].presence : nil),
            visible_to_filler: field_data[:visible_to_filler] == '1',
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

          # Store conditional answer reference (static mapping or table-lookup mode)
          next unless field_data[:conditional_answer_field_id].present?

          mappings = field_data[:conditional_answer_mappings].present? ? field_data[:conditional_answer_mappings].to_unsafe_h.reject { |_, v| v.blank? } : {}
          next unless field_data[:answer_mode] == 'lookup' || mappings.any?

          conditional_answer_refs << {
            field: field,
            ref: field_data[:conditional_answer_field_id],
            mappings: mappings.presence
          }
        end

        # Second pass: resolve conditional field references to actual IDs
        conditional_refs.each do |ref_data|
          if ref_data[:ref] =~ /^field_(\d+)$/
            ref_index = ::Regexp.last_match(1).to_i
            if created_fields[ref_index]
              ref_data[:field].update!(
                conditional_field_id: created_fields[ref_index].id,
                conditional_values: ref_data[:values]
              )
            end
          elsif ref_data[:ref].to_i.positive?
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
            ref_index = ::Regexp.last_match(1).to_i
            if created_fields[ref_index]
              ref_data[:field].update!(
                conditional_answer_field_id: created_fields[ref_index].id,
                conditional_answer_mappings: ref_data[:mappings]
              )
            end
          elsif ref_data[:ref].to_i.positive?
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
      generator_output, generator_status = run_rails_command('generate', 'paperboy_form', class_name)

      # Run db:migrate
      migrate_output, migrate_status = run_rails_command('db:migrate')

      # Check if generation was successful
      if generator_status.success? && migrate_status.success?
        # Customize generated model based on submission routing
        customize_generated_model(@form_template)

        # Customize generated controller based on submission routing
        customize_generated_controller(@form_template)

        # Add media download routes if needed
        add_media_download_routes(@form_template)

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
          message: 'Form created and generated successfully! The form should now appear in your sidebar.',
          warnings: routing_approver_warnings(@form_template),
          redirect: form_templates_path
        }
      else
        # If generation failed, delete the template
        @form_template.destroy
        render json: {
          success: false,
          errors: ["Generator failed: #{generator_output.presence || migrate_output}"]
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
    copy_recipients_changed = copy_recipients_fields_changed?
    email_steps_changed = email_steps_fields_changed?
    visibility_changed_to_public = @form_template.visibility != 'public' && form_template_params[:visibility] == 'public'

    # Set pending routing steps to pass validation (same as create)
    @form_template.pending_routing_steps = params[:routing_steps] if params[:routing_steps].present?

    if @form_template.update(form_template_params)
      # If visibility just changed to public, grant to all orgs and groups
      grant_to_all_scopes(@form_template) if visibility_changed_to_public
      # Only rebuild routing steps when routing actually changed
      rebuild_routing_steps(@form_template) if routing_changed

      # Only sync statuses when statuses or routing changed
      sync_statuses(@form_template) if statuses_changed || routing_changed

      # Rebuild copy recipients when they changed
      rebuild_copy_recipients(@form_template) if copy_recipients_changed

      # Rebuild workflow email steps when they changed
      rebuild_email_steps(@form_template) if email_steps_changed

      # Rebuild field records when fields changed (this is data, not code).
      rebuild_form_fields if fields_changed

      # Code generation (controller / views / model / routes) is skipped for
      # hand-coded forms — the builder still manages their routing/status/email
      # records above, but never overwrites their custom controller or views.
      if @form_template.skip_code_generation?
        Rails.logger.info "Skipping code generation for #{@form_template.class_name} (skip_code_generation)"
      else
        if fields_changed
          generate_dynamic_view(@form_template.class_name)
          generate_dynamic_edit_view(@form_template.class_name)
        end

        # Regenerate model when statuses, routing, or fields changed (enum + has_many_attached)
        customize_generated_model(@form_template) if statuses_changed || routing_changed || fields_changed

        if routing_changed || fields_changed
          customize_generated_controller(@form_template, update_routing: routing_changed)
          add_media_download_routes(@form_template)
          Rails.logger.info "Regenerated controller for #{@form_template.class_name}"
        end
      end

      message = if routing_changed
                  'Form template updated successfully. Controller was regenerated.'
                else
                  'Form template updated successfully.'
                end

      warnings = routing_approver_warnings(@form_template)

      respond_to do |format|
        format.json { render json: { success: true, message: message, warnings: warnings, redirect: form_template_path(@form_template) } }
        format.html { redirect_to form_template_path(@form_template), notice: [message, *warnings].join(' ') }
      end
    else
      respond_to do |format|
        format.json { render json: { success: false, errors: @form_template.errors.full_messages }, status: :unprocessable_entity }
        format.html do
          @acl_groups = fetch_acl_groups
          @employees = fetch_employees
          @fields_by_page = @form_template.form_fields.ordered.group_by(&:page_number)
          @agency_options = begin
            Agency.order(:long_name).pluck(:long_name, :agency_id)
          rescue StandardError
            []
          end
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
    sidebar_file = Rails.root.join('app/views/shared/_sidebar.html.erb')
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
    run_rails_command('generate', 'migration', migration_name)

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
      run_rails_command('db:migrate')
    end

    # 5. Run the destroy command to remove generated files
    run_rails_command('destroy', 'paperboy_form', class_name)

    # 6. Delete the template record
    if @form_template.destroy
      redirect_to form_templates_path, notice: 'Form template, generated files, database table, and sidebar entry deleted successfully.'
    else
      redirect_to form_templates_path, alert: 'Failed to delete form template.'
    end
  end

  def archive
    if @form_template.update(archived: true)
      redirect_to form_templates_path, notice: "#{@form_template.name} archived. It is now hidden from the sidebar."
    else
      redirect_to form_templates_path, alert: 'Failed to archive form template.'
    end
  end

  def unarchive
    if @form_template.update(archived: false)
      redirect_to form_templates_path, notice: "#{@form_template.name} restored to the sidebar."
    else
      redirect_to form_templates_path, alert: 'Failed to unarchive form template.'
    end
  end

  private

  def set_form_template
    @form_template = FormTemplate.find(params[:id])
  end

  def run_rails_command(*arguments)
    Open3.capture2e('bin/rails', *arguments, chdir: Rails.root.to_s)
  end

  def fix_sidebar_placement(class_name)
    sidebar = 'app/views/shared/_sidebar.html.erb'
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
    return unless sidebar_content.gsub!(/^\s*#{Regexp.escape(incorrect_line)}\s*\n/, '')

    File.write(sidebar, sidebar_content)
  end

  # When a new form is created, auto-grant it to any org scope or group
  # that currently has every existing form selected (i.e. Select All was on).
  def auto_grant_to_select_all_scopes(new_template)
    # Build the set of all form permission keys that existed BEFORE this template
    legacy_keys = AclController::LEGACY_FORMS.map { |f| f[:key] }
    template_names = FormTemplate.pluck(:name).to_set(&:downcase)
    legacy_keys.reject! { |k| template_names.include?(AclController::LEGACY_FORMS.find { |f| f[:key] == k }&.dig(:label)&.downcase) }
    existing_keys = legacy_keys + FormTemplate.where.not(id: new_template.id).pluck(:id).map(&:to_s)
    expected_count = existing_keys.size
    new_key = new_template.id.to_s

    # Org permissions: find scopes that had all forms selected
    OrgPermission.where(permission_type: 'form')
                 .select(:agency_id, :division_id, :department_id, :unit_id)
                 .group(:agency_id, :division_id, :department_id, :unit_id)
                 .having('COUNT(*) = ?', expected_count)
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
                   .having('COUNT(*) = ?', expected_count)
                   .each do |gp|
      GroupPermission.find_or_create_by!(
        group_id: gp.group_id,
        permission_type: 'form',
        permission_key: new_key
      )
    end
  rescue StandardError => e
    Rails.logger.warn "Auto-grant failed for template #{new_template.id}: #{e.message}"
  end

  def grant_to_all_scopes(template)
    permission_key = template.id.to_s

    # Grant to every distinct org scope that has any permissions
    existing_scopes = OrgPermission
                      .select(:agency_id, :division_id, :department_id, :unit_id)
                      .distinct
                      .to_set { |s| [s.agency_id, s.division_id, s.department_id, s.unit_id] }

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
  rescue StandardError => e
    Rails.logger.warn "Grant-to-all failed for template #{template.id}: #{e.message}"
  end

  def form_template_params
    params.require(:form_template).permit(
      :name,
      :visibility,
      :reference_prefix,
      :page_count,
      :submission_type,
      :approval_routing_to,
      :approval_employee_id,
      :has_dashboard,
      :records_table,
      :metabase_dashboard_id,
      :status_transition_mode,
      :tags,
      :skip_code_generation,
      page_headers: [],
      inbox_buttons: []
    )
  end

  # Normalize a custom (generic) lookup config from submitted field params.
  def build_custom_lookup(f)
    join_sep = f[:custom_join_separator].to_s
    cat_cols = Array(f[:custom_category_columns])
    cat_vals = Array(f[:custom_category_values])
    category_filters = cat_cols.each_with_index.filter_map do |col, i|
      col = col.to_s.strip
      next if col.blank?

      { 'column' => col, 'value' => cat_vals[i].to_s }
    end
    {
      'database' => f[:custom_database],
      'table' => f[:custom_table],
      'column' => f[:custom_column],
      'join_columns' => Array(f[:custom_join_columns]).reject(&:blank?),
      'join_separator' => (join_sep.empty? ? ' ' : join_sep),
      'category_filters' => category_filters,
      'order_column' => f[:custom_order_column].presence,
      'order_direction' => (f[:custom_order_direction] == 'desc' ? 'desc' : 'asc')
    }
  end

  # Data attributes wiring a field's conditional answer to its trigger on the
  # generated form. Lookup mode carries the field id (server resolves the DB
  # lookup at fill time); static mode inlines the value->value mapping JSON.
  def build_conditional_answer_attrs(field)
    return '' unless field.conditional_answer?

    answer_field = field.conditional_answer_field
    return '' unless answer_field

    if field.answer_lookup?
      " data-answer-depends-on=\"#{answer_field.field_name}\" data-answer-lookup-field-id=\"#{field.id}\""
    else
      mappings_json = field.conditional_answer_mappings.to_json.gsub('"', '&quot;')
      " data-answer-depends-on=\"#{answer_field.field_name}\" data-answer-mappings=\"#{mappings_json}\""
    end
  end

  # A field with has_custom_view keeps its HTML verbatim across regenerations,
  # but the conditional-answer attributes embed the field's DB id and trigger
  # name, and the id is reassigned every time fields are rebuilt. Left as-is a
  # preserved block points autofill at a since-deleted field id and silently
  # fills nothing. Refresh (or strip, or inject) those attrs from the current
  # field so preserved custom HTML keeps working.
  def refresh_conditional_answer_attrs(html, field)
    fresh = build_conditional_answer_attrs(field)
    # Matches the answer-lookup / answer-mappings attrs already on the wrapper.
    stale = /\s+data-answer-depends-on="[^"]*"(?:\s+data-answer-lookup-field-id="[^"]*"|\s+data-answer-mappings="[^"]*")/

    if html.match?(stale)
      html.sub(stale, fresh)
    elsif fresh.present?
      # Block predates the conditional-answer wiring — add it to the first tag.
      html.sub(/<(?:div|input|select|textarea)\b[^>]*/) { |tag| tag + fresh }
    else
      html
    end
  end

  def build_field_options(field_data)
    options = {}

    case field_data[:field_type]
    when 'text_box'
      options['rows'] = field_data[:rows].to_i if field_data[:rows].present?
    when 'dropdown', 'choices_dropdown'
      if field_data[:custom_table].present?
        options['custom_lookup'] = build_custom_lookup(field_data)
      elsif field_data[:data_source].present?
        options['data_source'] = field_data[:data_source]
        options['data_source_column'] = field_data[:data_source_column]
        options['data_source_agency'] = field_data[:data_source_agency] if field_data[:data_source_agency].present?
        options['data_source_category'] = field_data[:data_source_category] if field_data[:data_source_category].present?
      elsif field_data[:dropdown_values].present?
        options['values'] = field_data[:dropdown_values].split(',').map(&:strip)
      end
    when 'information'
      options['information_text'] = field_data[:information_text].to_s
      options['acknowledgeable'] = field_data[:acknowledgeable] == '1'
    end

    # Table-lookup answer mode is available on any field type, so it's folded in
    # after the per-type option build.
    if field_data[:answer_mode] == 'lookup' && field_data[:answer_lookup].present?
      al = field_data[:answer_lookup]
      if al[:table].present? && al[:match_column].present? && al[:return_column].present?
        join_sep = al[:return_join_separator].to_s
        options['answer_lookup'] = {
          'database' => al[:database].presence || 'paperboy',
          'table' => al[:table],
          'match_column' => al[:match_column],
          'return_column' => al[:return_column],
          'return_join_columns' => Array(al[:return_join_columns]).reject(&:blank?),
          'return_join_separator' => (join_sep.empty? ? ' ' : join_sep)
        }
      end
    end

    options
  end

  def fetch_acl_groups
    Group.order(:group_name).pluck(:group_name, :GroupID)
  rescue StandardError
    []
  end

  def fetch_employees
    Employee.order(:last_name, :first_name)
            .map { |e| ["#{e.first_name} #{e.last_name} (#{e.employee_id})", e.employee_id] }
  rescue StandardError
    []
  end

  def customize_generated_model(form_template)
    model_path = Rails.root.join("app/models/#{form_template.file_name}.rb")
    return unless File.exist?(model_path)

    content = File.read(model_path)

    if form_template.submission_type == 'database' && form_template.statuses.empty?
      # No statuses configured for database-only form — remove enum block
      content.gsub!(/^\s*enum :status.*?\n\s*\}(,\s*default:\s*:\w+)?/m, '')
      content.gsub!(/^\s*STATUS_CATEGORIES\s*=\s*\{.*?\}\.freeze/m, '')
      content.gsub!(/^\s*STATUS_LABELS\s*=\s*\{.*?\}\.freeze/m, '')
    else
      # Generate unified enum from all statuses (user + auto-generated)
      generate_unified_status_enum(form_template, content)
    end

    # Add has_many_attached declarations for media_attachment fields
    media_fields = form_template.form_fields.where(field_type: 'media_attachment')
    if media_fields.any?
      # Add only missing declarations (idempotent on re-runs)
      media_fields.each do |f|
        # Add has_many_attached if not already present
        unless content.include?("has_many_attached :#{f.field_name}")
          content.sub!("include TrackableStatus\n") do |match|
            "#{match}\n  has_many_attached :#{f.field_name}\n"
          end
        end

        # Add validate callback if not already present
        # Insert after validates :name line if it exists, otherwise after has_many_attached
        if !content.include?("validate :acceptable_#{f.field_name}_files") && (content =~ /validates :name.*\n/)
          content.sub!(/validates :name.*\n/) do |match|
            "#{match}  validate :acceptable_#{f.field_name}_files\n"
          end
        end

        # Add validation method if not already present
        next if content.include?("def acceptable_#{f.field_name}_files")

        validation_method = <<~RUBY

          def acceptable_#{f.field_name}_files
            return unless #{f.field_name}.attached?

            if #{f.field_name}.count > 10
              errors.add(:#{f.field_name}, "can have a maximum of 10 files")
            end

            #{f.field_name}.each do |file|
              unless file.content_type.in?(%w[image/jpeg image/png image/gif image/webp image/heic image/heif application/pdf])
                errors.add(:#{f.field_name}, "must be a JPEG, PNG, GIF, WebP, HEIC, or PDF")
              end

              if file.byte_size > 10.megabytes
                errors.add(:#{f.field_name}, "file size must be less than 10MB")
              end
            end
          end
        RUBY

        if content.include?("private\n")
          content.sub!(/^(\s*private\n)/) do |match|
            "#{validation_method}\n#{match}"
          end
        else
          content.sub!(/^end\s*\z/) do |match|
            "#{validation_method}\n#{match}"
          end
        end
      end
    end

    # Drop any per-model status_label override (and its doc comment); TrackableStatus
    # provides it by reading the central form_template_statuses table.
    content.gsub!(/(?:^[ \t]*#[^\n]*\n)*^[ \t]*def status_label\b.*?^[ \t]*end\b\n/m, '')
    content.gsub!(/\n{3,}/, "\n\n")

    File.write(model_path, content)
  end

  def generate_unified_status_enum(form_template, content)
    all_statuses = form_template.statuses.ordered.to_a
    return if all_statuses.empty?

    # Find the initial status
    initial_status = all_statuses.find(&:is_initial) || all_statuses.first
    default_key = initial_status.key

    # Build enum entries (string-backed: the column stores the key itself).
    # Indentation is baked in rather than using a squiggly heredoc, which would
    # only indent the first interpolated entry and leave the rest flush left.
    enum_entries = all_statuses.map do |status|
      "    #{status.key}: '#{status.key}'"
    end

    # Labels and categories are no longer copied into the model — they are read
    # at runtime from form_template_statuses (see TrackableStatus).
    new_block = "  enum :status, {\n#{enum_entries.join(",\n")}\n  }, default: :#{default_key}"

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
    content.sub!("include TrackableStatus\n") do |match|
      "#{match}\n#{new_block}\n"
    end
  end

  def customize_generated_controller(form_template, update_routing: true)
    controller_path = Rails.root.join("app/controllers/#{form_template.plural_file_name}_controller.rb")
    return unless File.exist?(controller_path)

    content = File.read(controller_path)

    # Safety net: never rewrite a controller the builder didn't generate. The
    # block-replacement below assumes the generated structure; on a hand-written
    # controller its regex can match greedily and destroy unrelated actions.
    unless content.include?('# Generated controller for')
      Rails.logger.warn "Refusing to customize hand-written controller #{controller_path} (no generated marker)"
      return
    end

    # Only update routing logic when routing actually changed (or on initial create)
    if update_routing && form_template.requires_approval?
      # Add routing logic to the create action
      routing_logic = generate_approval_routing_logic(form_template)

      # Replace the entire routing block between markers (idempotent on re-runs)
      if content.include?('# ROUTING_BLOCK_START')
        content.gsub!(
          /# ROUTING_BLOCK_START.*?# ROUTING_BLOCK_END/m,
          "# ROUTING_BLOCK_START\n      #{routing_logic}\n      # ROUTING_BLOCK_END"
        )
      else
        # Legacy controller without markers — replace entire save-success block
        # Match from after "if @form.save" up to "else" to avoid leaving stale routing code
        save_pattern = /(if @#{Regexp.escape(form_template.file_name)}\.save\n).+?(    else)/m
        if content.match?(save_pattern)
          replacement = "\\1      # ROUTING_BLOCK_START\n      #{routing_logic}\n      # ROUTING_BLOCK_END\n\\2"
          content.sub!(save_pattern, replacement)
        else
          # Absolute fallback — just replace the redirect line
          content.gsub!(
            /redirect_to form_success_path.*$/,
            "# ROUTING_BLOCK_START\n      #{routing_logic}\n      # ROUTING_BLOCK_END"
          )
        end
      end
    end

    # Add media attachment fields to permitted params
    media_fields = form_template.form_fields.where(field_type: 'media_attachment')
    if media_fields.any?
      media_params = media_fields.map { |f| "#{f.field_name}: []" }.join(', ')
      # Only append media params if not already present
      unless content.include?(media_params)
        content.gsub!(
          /(:name, :phone, :email, :agency, :division, :department, :unit)\s*\)/,
          "\\1,\n      #{media_params}\n    )"
        )
      end

      # Add download actions only if not already present
      media_fields.each do |f|
        next if content.include?("def download_#{f.field_name}")

        download_action = <<~RUBY
          def download_#{f.field_name}
            attachment = @#{form_template.file_name}.#{f.field_name}.find(params[:attachment_id])
            redirect_to rails_blob_path(attachment, disposition: "attachment")
          end

        RUBY

        content.sub!(/^\s*private\n/) do |match|
          "#{download_action}#{match}"
        end

        # Add download actions to before_action only if not already present
        method_sym = ":download_#{f.field_name}"
        next if content.include?(method_sym)

        content.sub!(
          /before_action :set_#{form_template.file_name}, only: \[([^\]]+)\]/,
          "before_action :set_#{form_template.file_name}, only: [\\1, #{method_sym}]"
        )
      end
    end

    File.write(controller_path, content)
  end

  def add_media_download_routes(form_template)
    media_fields = form_template.form_fields.where(field_type: 'media_attachment')
    return unless media_fields.any?

    routes_path = Rails.root.join('config/routes.rb')
    content = File.read(routes_path)

    media_fields.each do |field|
      route_line = "get :download_#{field.field_name}"
      # Only add if not already present
      next if content.include?(route_line)

      # Insert into the member block for this resource
      content.sub!(
        /(resources :#{form_template.plural_file_name} do\s*\n\s*member do\n)/,
        "\\1            #{route_line}\n"
      )
    end

    File.write(routes_path, content)
  end

  def routing_fields_changed?
    return false unless @form_template

    # Check if submission type changed
    return true if @form_template.submission_type != params[:form_template][:submission_type]

    # Check if routing steps changed
    current_steps = @form_template.routing_steps.ordered.map do |step|
      {
        routing_type: step.routing_type,
        employee_id: step.employee_id,
        group_id: step.group_id,
        org_filter_level: step.org_filter_level,
        authorization_service_type: step.authorization_service_type,
        display_name: step.display_name,
        condition_field_name: step.condition_field_name,
        condition_operator: step.condition_operator,
        condition_value: step.condition_value,
        inbox_buttons: step.inbox_buttons.sort
      }
    end

    new_steps = (params[:routing_steps] || []).map do |step|
      condition_field_name = step[:condition_field_name].presence
      group_routed = step[:routing_type] == 'group'
      authorization_routed = step[:routing_type] == 'authorization'
      {
        routing_type: step[:routing_type],
        employee_id: step[:employee_id]&.to_i.presence,
        group_id: step[:group_id]&.to_i.presence,
        org_filter_level: group_routed ? step[:org_filter_level].presence : nil,
        authorization_service_type: authorization_routed ? step[:authorization_service_type].presence : nil,
        display_name: step[:display_name].presence,
        condition_field_name: condition_field_name,
        condition_operator: condition_field_name ? step[:condition_operator].presence : nil,
        condition_value: condition_field_name ? step[:condition_value].presence : nil,
        inbox_buttons: extract_step_inbox_buttons(step).sort
      }
    end.reject { |s| s[:routing_type].blank? }

    current_steps != new_steps
  end

  def form_fields_changed?
    return false unless @form_template

    param_fields = params[:fields] || []

    current_fields = @form_template.form_fields.ordered.map do |f|
      {
        label: f.label, field_type: f.field_type, page_number: f.page_number,
        required: f.required, read_only: f.read_only || 'none',
        has_custom_view: f.has_custom_view, options: f.options,
        # Conditional dependency normalized to the *label* of the target field so
        # it can be compared against the field_N index refs the builder submits.
        conditional_on: f.conditional_field&.label,
        conditional_values: Array(f.conditional_values).map(&:to_s).sort,
        conditional_answer_on: f.conditional_answer_field&.label,
        conditional_answer_mappings: normalize_conditional_mappings(f.conditional_answer_mappings)
      }
    end

    # Resolve a submitted conditional ref (either "field_N" index into the
    # submitted fields, or a raw DB id) to the target field's label.
    resolve_ref_label = lambda do |ref|
      ref = ref.to_s
      if ref =~ /^field_(\d+)$/
        param_fields[::Regexp.last_match(1).to_i]&.dig(:label).presence
      elsif ref.to_i.positive?
        @form_template.form_fields.find_by(id: ref.to_i)&.label
      end
    end

    new_fields = param_fields.map do |f|
      {
        label: f[:label],
        field_type: f[:field_type],
        page_number: f[:page_number].to_i,
        required: f[:required] == '1',
        read_only: f[:read_only].presence || 'none',
        has_custom_view: f[:has_custom_view] == '1',
        conditional_on: resolve_ref_label.call(f[:conditional_field_id]),
        conditional_values: Array(f[:conditional_values]).reject(&:blank?).map(&:to_s).sort,
        conditional_answer_on: resolve_ref_label.call(f[:conditional_answer_field_id]),
        conditional_answer_mappings: normalize_conditional_mappings(f[:conditional_answer_mappings]),
        options: case f[:field_type]
                 when 'text_box' then { 'rows' => f[:rows].to_i }
                 when 'dropdown', 'choices_dropdown'
                   if f[:custom_table].present?
                     { 'custom_lookup' => build_custom_lookup(f) }
                   elsif f[:data_source].present?
                     opts = { 'data_source' => f[:data_source], 'data_source_column' => f[:data_source_column] }
                     opts['data_source_agency'] = f[:data_source_agency] if f[:data_source_agency].present?
                     opts['data_source_category'] = f[:data_source_category] if f[:data_source_category].present?
                     opts
                   elsif f[:dropdown_values].present?
                     { 'values' => f[:dropdown_values].split(',').map(&:strip) }
                   else
                     {}
                   end
                 when 'information'
                   {
                     'information_text' => f[:information_text].to_s,
                     'acknowledgeable' => f[:acknowledgeable] == '1'
                   }
                 else {}
                 end
      }
    end.reject { |f| f[:label].blank? }

    current_fields != new_fields
  end

  # Normalize conditional-answer mappings (from a DB JSON hash or submitted
  # params) into a plain hash with blank values stripped, for comparison.
  def normalize_conditional_mappings(raw)
    return {} if raw.blank?

    hash = raw.respond_to?(:to_unsafe_h) ? raw.to_unsafe_h : raw
    hash.to_h.transform_values(&:to_s).reject { |_, v| v.blank? }
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

      condition_field_name = step_data[:condition_field_name].presence
      group_routed = step_data[:routing_type] == 'group'
      authorization_routed = step_data[:routing_type] == 'authorization'
      form_template.routing_steps.create!(
        step_number: step_data[:step_number].to_i,
        routing_type: step_data[:routing_type],
        employee_id: step_data[:employee_id].presence,
        group_id: step_data[:group_id].presence,
        org_filter_level: group_routed ? step_data[:org_filter_level].presence : nil,
        authorization_service_type: authorization_routed ? step_data[:authorization_service_type].presence : nil,
        display_name: step_data[:display_name].presence,
        condition_field_name: condition_field_name,
        condition_operator: condition_field_name ? step_data[:condition_operator].presence : nil,
        condition_value: condition_field_name ? step_data[:condition_value].presence : nil,
        inbox_buttons: extract_step_inbox_buttons(step_data),
        approve_button_label: step_data[:approve_button_label].presence,
        deny_button_label: step_data[:deny_button_label].presence
      )
    end
  end

  # Non-blocking heads-up for routing steps that currently can't route to
  # anyone: an authorization step whose service type no employee holds, or a
  # group step whose group has no members. (supervisor/department_head/employee
  # depend on the runtime submitter, so they can't be pre-checked here.)
  def routing_approver_warnings(form_template)
    form_template.routing_steps.ordered.filter_map do |step|
      case step.routing_type
      when 'authorization'
        next if step.authorization_service_type.blank?

        if AuthorizedApprover.where(service_type: step.authorization_service_type).none?
          "Step #{step.step_number}: no employees currently hold the " \
            "'#{step.authorization_service_type_label}' authorization, so it may route to no one."
        end
      when 'group'
        next if step.group_id.blank?

        if EmployeeGroup.where(GroupID: step.group_id).none?
          "Step #{step.step_number}: the group '#{step.group_name || "##{step.group_id}"}' " \
            'has no members, so it may route to no one.'
        end
      end
    end
  end

  def extract_step_inbox_buttons(step_data)
    raw = step_data[:inbox_buttons]
    return [] if raw.blank?

    Array(raw).map(&:to_s).reject(&:blank?) & FormTemplate::INBOX_BUTTON_TYPES.keys
  end

  def save_copy_recipients(form_template)
    return unless params[:copy_recipients].present?

    params[:copy_recipients].each_with_index do |row, index|
      next if row[:recipient_type].blank?

      form_template.copy_recipients.create!(
        recipient_type: row[:recipient_type],
        employee_id: row[:recipient_type] == 'employee' ? row[:employee_id].presence : nil,
        group_id: row[:recipient_type] == 'group' ? row[:group_id].presence : nil,
        trigger_event: row[:trigger_event].presence || 'approval',
        position: index
      )
    end
  end

  def rebuild_copy_recipients(form_template)
    form_template.copy_recipients.destroy_all
    save_copy_recipients(form_template)
  end

  def copy_recipients_fields_changed?
    return false unless @form_template

    current = @form_template.copy_recipients.ordered.map do |r|
      {
        recipient_type: r.recipient_type,
        employee_id: r.employee_id,
        group_id: r.group_id,
        trigger_event: r.trigger_event
      }
    end

    incoming = (params[:copy_recipients] || []).map do |r|
      {
        recipient_type: r[:recipient_type],
        employee_id: r[:recipient_type] == 'employee' ? r[:employee_id]&.to_i.presence : nil,
        group_id: r[:recipient_type] == 'group' ? r[:group_id]&.to_i.presence : nil,
        trigger_event: r[:trigger_event].presence || 'approval'
      }
    end.reject { |r| r[:recipient_type].blank? }

    current != incoming
  end

  def save_email_steps(form_template)
    return unless params[:email_steps].present?

    params[:email_steps].each_with_index do |row, index|
      next if row[:recipient_type].blank?

      trigger = row[:trigger_event].presence || 'submit'
      step_bound = %w[approved denied].include?(trigger) && row[:routing_step_number].present?

      form_template.email_steps.create!(
        trigger_event: trigger,
        routing_step_number: step_bound ? row[:routing_step_number].to_i : nil,
        recipient_type: row[:recipient_type],
        employee_id: row[:recipient_type] == 'employee' ? row[:employee_id].presence : nil,
        group_id: row[:recipient_type] == 'group' ? row[:group_id].presence : nil,
        custom_email: row[:recipient_type] == 'custom_email' ? row[:custom_email].presence : nil,
        recipient_field_name: row[:recipient_type] == 'form_field' ? row[:recipient_field_name].presence : nil,
        subject: row[:subject].presence,
        body: row[:body].presence,
        attach_pdf: row[:attach_pdf] == '1',
        attach_media: row[:attach_media] == '1',
        position: index
      )
    end
  end

  def rebuild_email_steps(form_template)
    form_template.email_steps.destroy_all
    save_email_steps(form_template)
  end

  def email_steps_fields_changed?
    return false unless @form_template

    current = @form_template.email_steps.ordered.map do |e|
      {
        trigger_event: e.trigger_event,
        routing_step_number: e.routing_step_number,
        recipient_type: e.recipient_type,
        employee_id: e.employee_id,
        group_id: e.group_id,
        custom_email: e.custom_email,
        recipient_field_name: e.recipient_field_name,
        subject: e.subject,
        body: e.body,
        attach_pdf: e.attach_pdf,
        attach_media: e.attach_media
      }
    end

    incoming = (params[:email_steps] || []).map do |r|
      trigger = r[:trigger_event].presence || 'submit'
      step_bound = %w[approved denied].include?(trigger) && r[:routing_step_number].present?
      {
        trigger_event: trigger,
        routing_step_number: step_bound ? r[:routing_step_number].to_i : nil,
        recipient_type: r[:recipient_type],
        employee_id: r[:recipient_type] == 'employee' ? r[:employee_id]&.to_i.presence : nil,
        group_id: r[:recipient_type] == 'group' ? r[:group_id]&.to_i.presence : nil,
        custom_email: r[:recipient_type] == 'custom_email' ? r[:custom_email].presence : nil,
        recipient_field_name: r[:recipient_type] == 'form_field' ? r[:recipient_field_name].presence : nil,
        subject: r[:subject].presence,
        body: r[:body].presence,
        attach_pdf: r[:attach_pdf] == '1',
        attach_media: r[:attach_media] == '1'
      }
    end.reject { |r| r[:recipient_type].blank? }

    current != incoming
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

      params[:statuses].each_with_index do |status_data, _index|
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
        name: 'In Progress', key: 'in_progress', category: 'pending',
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

      condition_field_name = step_data[:condition_field_name].presence
      group_routed = step_data[:routing_type] == 'group'
      authorization_routed = step_data[:routing_type] == 'authorization'
      form_template.routing_steps.create!(
        step_number: index + 1,
        routing_type: step_data[:routing_type],
        employee_id: step_data[:employee_id].presence,
        group_id: step_data[:group_id].presence,
        org_filter_level: group_routed ? step_data[:org_filter_level].presence : nil,
        authorization_service_type: authorization_routed ? step_data[:authorization_service_type].presence : nil,
        display_name: step_data[:display_name].presence,
        condition_field_name: condition_field_name,
        condition_operator: condition_field_name ? step_data[:condition_operator].presence : nil,
        condition_value: condition_field_name ? step_data[:condition_value].presence : nil,
        inbox_buttons: extract_step_inbox_buttons(step_data),
        approve_button_label: step_data[:approve_button_label].presence,
        deny_button_label: step_data[:deny_button_label].presence
      )
    end

    # Clear legacy routing fields when using routing steps
    return unless form_template.routing_steps.any?

    form_template.update_columns(approval_routing_to: nil, approval_employee_id: nil)
  end

  def rebuild_form_fields
    # Preserve existing field_names before destroying (keyed by label)
    # so manually-corrected column names survive rebuild
    existing_field_names = @form_template.form_fields.pluck(:label, :field_name).to_h

    # Preserve existing conditional wiring (keyed by source-field label, with the
    # *target* field referenced by label too) so links survive the destroy/recreate
    # even when the builder UI fails to resubmit them (e.g. it resets the trigger
    # select or value checkboxes on reorder/add/remove). Submitted params still win.
    existing_conditionals = @form_template.form_fields.ordered.each_with_object({}) do |f, acc|
      next unless f.conditional? || f.conditional_answer?

      acc[f.label] = {
        on_label: f.conditional_field&.label,
        values: Array(f.conditional_values),
        answer_on_label: f.conditional_answer_field&.label,
        answer_mappings: f.conditional_answer_mappings
      }
    end

    @form_template.form_fields.destroy_all

    return unless params[:fields].present?

    # First pass: create all fields, store conditional references
    created_fields = []
    conditional_refs = []
    conditional_answer_refs = []
    # Fields the user explicitly toggled OFF — these must NOT be restored from
    # the pre-rebuild snapshot even though they submit no conditional data.
    disabled_conditional = []
    disabled_answer = []

    params[:fields].each_with_index do |field_data, index|
      field = @form_template.form_fields.create!(
        label: field_data[:label],
        field_name: existing_field_names[field_data[:label]],
        field_type: field_data[:field_type],
        page_number: field_data[:page_number].to_i,
        position: index,
        required: field_data[:required] == '1',
        options: build_field_options(field_data),
        restricted_to_type: field_data[:restricted_to_type].presence || 'none',
        restricted_to_employee_id: field_data[:restricted_to_employee_id].presence,
        restricted_to_group_id: field_data[:restricted_to_group_id].presence,
        restricted_to_org_filter_level: (field_data[:restricted_to_type] == 'group' ? field_data[:restricted_to_org_filter_level].presence : nil),
        visible_to_filler: field_data[:visible_to_filler] == '1',
        read_only: field_data[:read_only].presence || 'none',
        has_custom_view: field_data[:has_custom_view] == '1'
      )
      created_fields << field
      disabled_conditional << field if field_data[:conditional_enabled] == '0'
      disabled_answer << field if field_data[:conditional_answer_enabled] == '0'

      # Store conditional reference if present
      if field_data[:conditional_field_id].present? && field_data[:conditional_values].present?
        conditional_refs << {
          field: field,
          ref: field_data[:conditional_field_id],
          values: Array(field_data[:conditional_values]).reject(&:blank?)
        }
      end

      # Store conditional answer reference (static mapping or table-lookup mode)
      next unless field_data[:conditional_answer_field_id].present?

      mappings = field_data[:conditional_answer_mappings].present? ? field_data[:conditional_answer_mappings].to_unsafe_h.reject { |_, v| v.blank? } : {}
      next unless field_data[:answer_mode] == 'lookup' || mappings.any?

      conditional_answer_refs << {
        field: field,
        ref: field_data[:conditional_answer_field_id],
        mappings: mappings.presence
      }
    end

    # Second pass: resolve conditional field references to actual IDs
    conditional_refs.each do |ref_data|
      if ref_data[:ref] =~ /^field_(\d+)$/
        ref_index = ::Regexp.last_match(1).to_i
        if created_fields[ref_index]
          ref_data[:field].update!(
            conditional_field_id: created_fields[ref_index].id,
            conditional_values: ref_data[:values]
          )
        end
      elsif ref_data[:ref].to_i.positive?
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
        ref_index = ::Regexp.last_match(1).to_i
        if created_fields[ref_index]
          ref_data[:field].update!(
            conditional_answer_field_id: created_fields[ref_index].id,
            conditional_answer_mappings: ref_data[:mappings]
          )
        end
      elsif ref_data[:ref].to_i.positive?
        ref_data[:field].update!(
          conditional_answer_field_id: ref_data[:ref].to_i,
          conditional_answer_mappings: ref_data[:mappings]
        )
      end
    end

    # Restore any conditional wiring the submission dropped. Fields whose params
    # carried a conditional, or that the user explicitly toggled off, are left
    # untouched so intentional edits win; the rest fall back to the pre-rebuild
    # snapshot, resolving the target by label.
    fields_with_param_conditional = conditional_refs.map { |r| r[:field] }
    fields_with_param_answer = conditional_answer_refs.map { |r| r[:field] }

    created_fields.each do |field|
      snap = existing_conditionals[field.label]
      next unless snap

      if snap[:on_label].present? && snap[:values].any? &&
         !fields_with_param_conditional.include?(field) && !disabled_conditional.include?(field)
        target = created_fields.find { |c| c.label == snap[:on_label] }
        field.update!(conditional_field_id: target.id, conditional_values: snap[:values]) if target
      end

      next unless snap[:answer_on_label].present? && snap[:answer_mappings].present?
      next if fields_with_param_answer.include?(field) || disabled_answer.include?(field)

      target = created_fields.find { |c| c.label == snap[:answer_on_label] }
      field.update!(conditional_answer_field_id: target.id, conditional_answer_mappings: snap[:answer_mappings]) if target
    end
  end

  def generate_approval_routing_logic(form_template)
    # Check if using multi-step routing
    return generate_multi_step_routing_logic(form_template) if form_template.routing_steps.any?

    # Legacy single-step routing
    # Use the actual first status from the form's statuses
    pending_status = form_template.statuses.find_by(category: 'pending')&.key ||
                     form_template.statuses.ordered.first&.key ||
                     'pending'
    table_name = begin
      form_template.class_name.constantize.table_name
    rescue StandardError
      form_template.table_name
    end
    has_approver = begin
      ActiveRecord::Base.connection.column_exists?(table_name, :approver_id)
    rescue StandardError
      false
    end

    case form_template.approval_routing_to
    when 'supervisor'
      <<~RUBY.chomp
        # Route to supervisor for approval
        @#{form_template.file_name}.update(status: :#{pending_status})
        # TODO: Send notification to supervisor
        redirect_to form_success_path, notice: 'Form submitted and routed to your supervisor for approval.', allow_other_host: false, status: :see_other
      RUBY
    when 'department_head'
      <<~RUBY.chomp
        # Route to department head for approval
        @#{form_template.file_name}.update(status: :#{pending_status})
        # TODO: Send notification to department head
        redirect_to form_success_path, notice: 'Form submitted and routed to your department head for approval.', allow_other_host: false, status: :see_other
      RUBY
    when 'employee'
      update_attrs = "status: :#{pending_status}"
      update_attrs += ", approver_id: #{form_template.approval_employee_id}" if has_approver
      <<~RUBY.chomp
        # Route to specific employee for approval
        @#{form_template.file_name}.update(#{update_attrs})
        # TODO: Send notification to employee with ID #{form_template.approval_employee_id}
        redirect_to form_success_path, notice: 'Form submitted and routed for approval.', allow_other_host: false, status: :see_other
      RUBY
    else
      'redirect_to form_success_path, allow_other_host: false, status: :see_other'
    end
  end

  def generate_multi_step_routing_logic(form_template)
    steps = form_template.routing_steps.ordered

    <<~RUBY.chomp
      # Multi-step approval routing (#{steps.count} steps)
      # Delegates to TrackableStatus#start_approval!, which picks the first
      # step whose condition matches the submitted record.
      @#{form_template.file_name}.start_approval!
      redirect_to form_success_path, notice: 'Form submitted and routed for approval.', allow_other_host: false, status: :see_other
    RUBY
  end

  def generate_dynamic_view(class_name)
    form_template = FormTemplate.find_by(class_name: class_name)
    return unless form_template

    view_path = Rails.root.join("app/views/#{form_template.plural_file_name}/new.html.erb")

    # Extract existing custom field blocks before regenerating
    existing_blocks = extract_existing_field_blocks(view_path)

    # Determine which Stimulus controllers to attach
    controllers = ['form-navigation']
    controllers << 'conditional-fields' if form_template.form_fields.conditional.any? || form_template.form_fields.any?(&:conditional_answer?)
    controllers_attr = controllers.join(' ')

    page_visibility = (1..form_template.page_count).to_h do |n|
      [n, generate_page_visibility_check(form_template, n)]
    end

    # Build the dynamic view content
    content = <<~HTML
      <!-- Generated by Paperboy Form Builder -->
      <div class="form-header">
        <h1>#{form_template.name}</h1>
      </div>

      <div class="form-wrapper" data-controller="#{controllers_attr}">
        <%= form_with model: @#{form_template.file_name}, local: true do |form| %>

        <% if @#{form_template.file_name}.errors.any? %>
          <div class="form-errors" role="alert" data-form-navigation-target="errorSummary">
            <strong><%= pluralize(@#{form_template.file_name}.errors.count, "error") %> prevented this form from being submitted:</strong>
            <ul>
              <% @#{form_template.file_name}.errors.each do |error| %>
                <li><%= error.full_message %></li>
              <% end %>
            </ul>
          </div>
        <% end %>

    HTML

    content += render_page_visibility_decls(page_visibility)

    # Generate each page
    (1..form_template.page_count).each do |page_num|
      page_header = form_template.page_header(page_num)
      fields_for_page = form_template.form_fields.for_page(page_num)

      display_style = page_num == 1 ? '' : ' style="display:none;"'

      content += "        <% if _page_#{page_num}_visible %>\n" if page_visibility[page_num]

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
          content += "<!-- FIELD:#{field.field_name} START -->"
          content += if field.has_custom_view && existing_blocks[field.field_name]
                       # Preserve the custom HTML, but refresh the autofill attrs
                       # so a rebuilt field id can't leave a stale reference.
                       refresh_conditional_answer_attrs(existing_blocks[field.field_name], field)
                     else
                       generate_field_html(field, form_template)
                     end
          content += "<!-- FIELD:#{field.field_name} END -->\n"
        end

        content += "        </div>\n"
      end

      content += "      </div>\n"
      content += "        <% end %>\n" if page_visibility[page_num]
      content += "\n"
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
              <% _visible_page_count.times do |index| %>
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

    # Extract existing custom field blocks before regenerating
    existing_blocks = extract_existing_field_blocks(view_path)

    # Determine which Stimulus controllers to attach
    controllers = ['form-navigation']
    controllers << 'conditional-fields' if form_template.form_fields.conditional.any? || form_template.form_fields.any?(&:conditional_answer?)
    controllers_attr = controllers.join(' ')

    page_visibility = (1..form_template.page_count).to_h do |n|
      [n, generate_page_visibility_check(form_template, n)]
    end

    # Build the dynamic edit view content
    content = <<~HTML
      <!-- Generated by Paperboy Form Builder -->
      <div class="form-header">
        <h1>Edit #{form_template.name}</h1>
      </div>

      <div class="form-wrapper" data-controller="#{controllers_attr}">
        <%= form_with model: @#{form_template.file_name}, local: true do |form| %>

        <% if @#{form_template.file_name}.errors.any? %>
          <div class="form-errors" role="alert" data-form-navigation-target="errorSummary">
            <strong><%= pluralize(@#{form_template.file_name}.errors.count, "error") %> prevented this form from being submitted:</strong>
            <ul>
              <% @#{form_template.file_name}.errors.each do |error| %>
                <li><%= error.full_message %></li>
              <% end %>
            </ul>
          </div>
        <% end %>

    HTML

    content += render_page_visibility_decls(page_visibility)

    # Generate each page
    (1..form_template.page_count).each do |page_num|
      page_header = form_template.page_header(page_num)
      fields_for_page = form_template.form_fields.for_page(page_num)

      display_style = page_num == 1 ? '' : ' style="display:none;"'

      content += "        <% if _page_#{page_num}_visible %>\n" if page_visibility[page_num]

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
          content += "<!-- FIELD:#{field.field_name} START -->"
          content += if field.has_custom_view && existing_blocks[field.field_name]
                       # Preserve the custom HTML, but refresh the autofill attrs
                       # so a rebuilt field id can't leave a stale reference.
                       refresh_conditional_answer_attrs(existing_blocks[field.field_name], field)
                     else
                       generate_field_html_for_edit(field, form_template)
                     end
          content += "<!-- FIELD:#{field.field_name} END -->\n"
        end

        content += "        </div>\n"
      end

      content += "      </div>\n"
      content += "        <% end %>\n" if page_visibility[page_num]
      content += "\n"
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
              <% _visible_page_count.times do |index| %>
                <div class="dot <%= 'active' if index == 0 %>"></div>
              <% end %>
            </div>
          </div>

        <% end %>
      </div>
    HTML

    File.write(view_path, content)
  end

  def generate_employee_info_fields_for_edit(_form_template)
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
          <%= form.label :division, "Division", data: { gsabss_selects_target: "divisionLabel" } %>
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
          <%= form.label :department, "Department", data: { gsabss_selects_target: "departmentLabel" } %>
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
      editable_check = generate_editable_check(field, form_template)
      required_logic = field.required ? "required: field_#{field.id}_editable && #{field.required}" : ''
      disabled_attr = "disabled: !field_#{field.id}_editable"
      restriction_label = field.restriction_label
    else
      editable_check = nil
      required_logic = field.required ? 'required: true' : ''
      disabled_attr = nil
      restriction_label = nil
    end

    # Generate conditional attributes with initial visibility based on model value
    conditional_wrapper_start = ''
    conditional_wrapper_end = ''
    if field.conditional?
      conditional_field = field.conditional_field
      if conditional_field
        values_json = field.conditional_values.to_json.gsub('"', '&quot;')
        # For edit view, show conditional fields based on current model values
        conditional_wrapper_start = "          <div class=\"conditional-field\" data-depends-on=\"#{conditional_field.field_name}\" data-show-values=\"#{values_json}\" style=\"<%= #{field.conditional_values.inspect}.include?(@#{form_template.file_name}.#{conditional_field.field_name}) ? '' : 'display: none;' %>\">\n"
        conditional_wrapper_end = "          </div>\n"
        # For conditional fields, don't require them initially (JS will handle validation)
        required_logic = '' if field.required
      end
    end

    # Read-only handling: on edit view, only 'always' is readonly ('initial' becomes editable)
    is_read_only = field.read_only_always?
    readonly_attr = is_read_only ? 'readonly: true' : nil

    # Generate conditional answer data attributes for the form-group div
    conditional_answer_attrs = build_conditional_answer_attrs(field)

    # Build attributes hash string
    attrs = ["class: \"form-control#{' field-readonly' if is_read_only}\""]
    attrs << required_logic if required_logic.present?
    attrs << disabled_attr if disabled_attr.present?
    attrs << readonly_attr if readonly_attr.present?
    # Add data attribute for dropdowns that have conditional dependencies
    attrs << "data: { conditional_trigger: '#{field.field_name}' }" if (field.dropdown? || field.choices_dropdown?) && conditional_dependents?(field)
    attrs_str = attrs.join(', ')

    # For select/dropdown fields, use disabled instead of readonly (readonly doesn't work on selects)
    select_attrs = attrs.reject { |a| a == 'readonly: true' }
    select_attrs << 'disabled: true' if is_read_only && disabled_attr.nil?
    select_attrs_str = select_attrs.join(', ')

    case field.field_type
    when 'text'
      html = ''
      html += "        <% #{editable_check} %>\n" if editable_check
      html += conditional_wrapper_start
      html += <<~HTML
        <div class="form-group flex-fill<%= #{editable_check ? "' field-restricted' unless field_#{field.id}_editable" : "''"} %>"#{conditional_answer_attrs}>
          <%= form.label :#{field.field_name}, "#{field.label}" %>
      HTML
      html += "            <small class=\"restriction-notice\">#{restriction_label}</small>\n" if restriction_label
      html += "            <%= form.text_field :#{field.field_name}, #{attrs_str} %>\n"
      html += "          </div>\n"
      html += conditional_wrapper_end
      html
    when 'text_box'
      html = ''
      html += "        <% #{editable_check} %>\n" if editable_check
      html += conditional_wrapper_start
      html += <<~HTML
        <div class="form-group flex-fill<%= #{editable_check ? "' field-restricted' unless field_#{field.id}_editable" : "''"} %>"#{conditional_answer_attrs}>
          <%= form.label :#{field.field_name}, "#{field.label}" %>
      HTML
      html += "            <small class=\"restriction-notice\">#{restriction_label}</small>\n" if restriction_label
      html += "            <%= form.text_area :#{field.field_name}, rows: #{field.rows}, #{attrs_str} %>\n"
      html += "          </div>\n"
      html += conditional_wrapper_end
      html
    when 'dropdown'
      if field.custom_lookup?
        options_expr = "FormLookup.options(#{field.id})"
      elsif field.data_source?
        options_expr = field.data_source_query_code
      else
        options = field.dropdown_values.map { |v| "'#{v}'" }.join(', ')
        options_expr = "[#{options}]"
      end
      selected_expr = "@#{form_template.file_name}.#{field.field_name}"
      html = ''
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
    when 'choices_dropdown'
      if field.custom_lookup?
        options_expr = "FormLookup.options(#{field.id})"
      elsif field.data_source?
        options_expr = field.data_source_query_code
      else
        options = field.dropdown_values.map { |v| "'#{v}'" }.join(', ')
        options_expr = "[#{options}]"
      end
      # Build merged data hash for choices_dropdown (avoid duplicate data: keys)
      data_entries = ['choices_target: "select"', 'placeholder: "Select options..."']
      data_entries << "conditional_trigger: '#{field.field_name}'" if conditional_dependents?(field)
      # Use select_attrs without the standalone data: key (we merge it into one)
      choices_attrs = select_attrs.reject { |a| a.start_with?('data:') }
      choices_attrs_str = choices_attrs.join(', ')
      html = ''
      html += "        <% #{editable_check} %>\n" if editable_check
      html += conditional_wrapper_start
      html += <<~HTML
        <div class="form-group flex-fill<%= #{editable_check ? "' field-restricted' unless field_#{field.id}_editable" : "''"} %>"#{conditional_answer_attrs} data-controller="choices">
          <%= form.label :#{field.field_name}, "#{field.label}" %>
      HTML
      html += "            <small class=\"restriction-notice\">#{restriction_label}</small>\n" if restriction_label
      html += "            <%= form.select :#{field.field_name},\n"
      # Pre-select the saved values on edit. Stored as a comma-joined string;
      # split on commas NOT followed by a space so values that contain a comma
      # (e.g. "Last, First" names) survive the round-trip.
      html += "                  options_for_select(#{options_expr}, @#{form_template.file_name}.#{field.field_name}.to_s.split(/,(?! )/)),\n"
      html += "                  { include_blank: false },\n"
      html += "                  { #{choices_attrs_str}, multiple: true, data: { #{data_entries.join(', ')} } } %>\n"
      html += "          </div>\n"
      html += conditional_wrapper_end
      html
    when 'date'
      html = ''
      html += "        <% #{editable_check} %>\n" if editable_check
      html += conditional_wrapper_start
      html += <<~HTML
        <div class="form-group flex-fill<%= #{editable_check ? "' field-restricted' unless field_#{field.id}_editable" : "''"} %>"#{conditional_answer_attrs}>
          <%= form.label :#{field.field_name}, "#{field.label}" %>
      HTML
      html += "            <small class=\"restriction-notice\">#{restriction_label}</small>\n" if restriction_label
      html += "            <%= form.date_field :#{field.field_name}, #{attrs_str} %>\n"
      html += "          </div>\n"
      html += conditional_wrapper_end
      html
    when 'date_time'
      html = ''
      html += "        <% #{editable_check} %>\n" if editable_check
      html += conditional_wrapper_start
      html += <<~HTML
        <div class="form-group flex-fill<%= #{editable_check ? "' field-restricted' unless field_#{field.id}_editable" : "''"} %>"#{conditional_answer_attrs}>
          <%= form.label :#{field.field_name}, "#{field.label}" %>
      HTML
      html += "            <small class=\"restriction-notice\">#{restriction_label}</small>\n" if restriction_label
      html += "            <%= form.datetime_local_field :#{field.field_name}, #{attrs_str} %>\n"
      html += "          </div>\n"
      html += conditional_wrapper_end
      html
    when 'phone'
      phone_id = field.field_name.camelize(:lower)
      phone_attrs = ["class: \"form-control#{' field-readonly' if is_read_only}\""]
      phone_attrs << required_logic if required_logic.present?
      phone_attrs << disabled_attr if disabled_attr.present?
      phone_attrs << readonly_attr if readonly_attr.present?
      phone_attrs << 'placeholder: "e.g. 555-555-5555"'
      phone_attrs << 'title: "Enter a 10-digit phone number like 555-555-5555"'
      phone_attrs << 'data: { controller: "phone", phone_target: "input", action: "input->phone#format paste->phone#format blur->phone#validate" }'
      phone_attrs << "\"aria-describedby\": \"#{phone_id}Help #{phone_id}Error\""
      phone_attrs << 'pattern: "\\\\d{3}-\\\\d{3}-\\\\d{4}"'
      phone_attrs << 'inputmode: "numeric"'
      phone_attrs << 'autocomplete: "tel"'
      phone_attrs_str = phone_attrs.join(",\n                  ")
      html = ''
      html += "        <% #{editable_check} %>\n" if editable_check
      html += conditional_wrapper_start
      html += <<~HTML
        <div class="form-group flex-fill<%= #{editable_check ? "' field-restricted' unless field_#{field.id}_editable" : "''"} %>"#{conditional_answer_attrs}>
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
      email_attrs = ["class: \"form-control#{' field-readonly' if is_read_only}\""]
      email_attrs << required_logic if required_logic.present?
      email_attrs << disabled_attr if disabled_attr.present?
      email_attrs << readonly_attr if readonly_attr.present?
      email_attrs << 'placeholder: "e.g. name@example.com"'
      email_attrs << 'autocomplete: "email"'
      email_attrs_str = email_attrs.join(', ')
      html = ''
      html += "        <% #{editable_check} %>\n" if editable_check
      html += conditional_wrapper_start
      html += <<~HTML
        <div class="form-group flex-fill<%= #{editable_check ? "' field-restricted' unless field_#{field.id}_editable" : "''"} %>"#{conditional_answer_attrs}>
          <%= form.label :#{field.field_name}, "#{field.label}" %>
      HTML
      html += "            <small class=\"restriction-notice\">#{restriction_label}</small>\n" if restriction_label
      html += "            <%= form.email_field :#{field.field_name}, #{email_attrs_str} %>\n"
      html += "          </div>\n"
      html += conditional_wrapper_end
      html
    when 'number'
      html = ''
      html += "        <% #{editable_check} %>\n" if editable_check
      html += conditional_wrapper_start
      html += <<~HTML
        <div class="form-group flex-fill<%= #{editable_check ? "' field-restricted' unless field_#{field.id}_editable" : "''"} %>"#{conditional_answer_attrs}>
          <%= form.label :#{field.field_name}, "#{field.label}" %>
      HTML
      html += "            <small class=\"restriction-notice\">#{restriction_label}</small>\n" if restriction_label
      html += "            <%= form.number_field :#{field.field_name}, #{attrs_str} %>\n"
      html += "          </div>\n"
      html += conditional_wrapper_end
      html
    when 'currency'
      currency_attrs = attrs.dup
      currency_attrs << 'step: "0.01"'
      currency_attrs << 'min: "0"'
      currency_attrs_str = currency_attrs.join(', ')
      html = ''
      html += "        <% #{editable_check} %>\n" if editable_check
      html += conditional_wrapper_start
      html += <<~HTML
        <div class="form-group flex-fill<%= #{editable_check ? "' field-restricted' unless field_#{field.id}_editable" : "''"} %>"#{conditional_answer_attrs}>
          <%= form.label :#{field.field_name}, "#{field.label}" %>
      HTML
      html += "            <small class=\"restriction-notice\">#{restriction_label}</small>\n" if restriction_label
      html += "            <div class=\"currency-input-wrapper\">\n"
      html += "              <span class=\"currency-prefix\">$</span>\n"
      html += "              <%= form.number_field :#{field.field_name}, #{currency_attrs_str} %>\n"
      html += "            </div>\n"
      html += "          </div>\n"
      html += conditional_wrapper_end
      html
    when 'yes_no'
      html = ''
      html += "        <% #{editable_check} %>\n" if editable_check
      html += conditional_wrapper_start
      html += <<~HTML
        <div class="form-group flex-fill<%= #{editable_check ? "' field-restricted' unless field_#{field.id}_editable" : "''"} %>"#{conditional_answer_attrs}>
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
      html = ''
      html += "        <% #{editable_check} %>\n" if editable_check
      html += conditional_wrapper_start
      html += <<~HTML
        <div class="form-group flex-fill<%= #{editable_check ? "' field-restricted' unless field_#{field.id}_editable" : "''"} %>"#{conditional_answer_attrs}>
          <%= form.label :#{field.field_name}, "#{field.label}" %>
      HTML
      html += "            <small class=\"restriction-notice\">#{restriction_label}</small>\n" if restriction_label
      html += "            <%= form.time_field :#{field.field_name}, #{attrs_str} %>\n"
      html += "          </div>\n"
      html += conditional_wrapper_end
      html
    when 'media_attachment'
      html = ''
      html += "        <% #{editable_check} %>\n" if editable_check
      html += conditional_wrapper_start
      html += <<~HTML
        <div class="form-group flex-fill<%= #{editable_check ? "' field-restricted' unless field_#{field.id}_editable" : "''"} %>" data-controller="file-preview" data-file-preview-max-value="10">
          <%= form.label :#{field.field_name}, "#{field.label}" %>
      HTML
      html += "            <small class=\"restriction-notice\">#{restriction_label}</small>\n" if restriction_label
      # Show existing attachments on edit
      html += "            <% if @#{form_template.file_name}.#{field.field_name}.attached? %>\n"
      html += "              <div class=\"existing-attachments\">\n"
      html += "                <small class=\"form-text text-muted\">Currently attached:</small>\n"
      html += "                <div class=\"file-preview-grid\">\n"
      html += "                  <% @#{form_template.file_name}.#{field.field_name}.each do |attachment| %>\n"
      html += "                    <div class=\"file-preview-item\">\n"
      html += "                      <% if attachment.content_type.start_with?('image/') %>\n"
      html += "                        <%= image_tag rails_blob_path(attachment, disposition: 'inline'), class: 'file-preview-thumb' %>\n"
      html += "                      <% else %>\n"
      html += "                        <div class=\"file-preview-icon\"><i class=\"fas fa-file-pdf\"></i></div>\n"
      html += "                      <% end %>\n"
      html += "                      <span class=\"file-preview-name\"><%= attachment.filename %></span>\n"
      html += "                    </div>\n"
      html += "                  <% end %>\n"
      html += "                </div>\n"
      html += "              </div>\n"
      html += "            <% end %>\n"
      html += "            <%= form.file_field :#{field.field_name}, multiple: true, class: \"form-control\", direct_upload: true, accept: \"image/jpeg,image/png,image/gif,image/webp,image/heic,image/heif,application/pdf\""
      html += ', disabled: true' if disabled_attr.present?
      html += ", data: { file_preview_target: \"input\", action: \"change->file-preview#preview\" } %>\n"
      html += "            <small class=\"form-text text-muted\">You can select files multiple times — up to 10 total. <span data-file-preview-target=\"count\"></span></small>\n"
      html += "            <div data-file-preview-target=\"preview\" class=\"file-preview-grid\"></div>\n"
      html += "          </div>\n"
      html += conditional_wrapper_end
      html
    when 'information'
      html = ''
      html += conditional_wrapper_start
      html += generate_information_field_html(field)
      html += conditional_wrapper_end
      html
    end.then { |rendered| wrap_visibility(field, editable_check, rendered) }
  end

  # Extract existing field blocks from a view file using marker comments.
  # Returns a hash of { field_name => html_block } for fields wrapped in
  # <!-- FIELD:field_name START --> ... <!-- FIELD:field_name END --> markers.
  def extract_existing_field_blocks(view_path)
    return {} unless File.exist?(view_path)

    existing_content = File.read(view_path)
    blocks = {}
    existing_content.scan(/<!-- FIELD:(\w+) START -->(.+?)<!-- FIELD:\1 END -->/m) do |name, html|
      blocks[name] = html
    end
    blocks
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
          <%= form.label :division, "Division", data: { gsabss_selects_target: "divisionLabel" } %>
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
          <%= form.label :department, "Department", data: { gsabss_selects_target: "departmentLabel" } %>
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

  def generate_field_html(field, form_template)
    # Generate restriction check and attributes
    if field.restricted?
      editable_check = generate_editable_check(field, form_template)
      required_logic = field.required ? "required: field_#{field.id}_editable && #{field.required}" : ''
      disabled_attr = "disabled: !field_#{field.id}_editable"
      restriction_label = field.restriction_label
    else
      editable_check = nil
      required_logic = field.required ? 'required: true' : ''
      disabled_attr = nil
      restriction_label = nil
    end

    # Generate conditional attributes
    conditional_wrapper_start = ''
    conditional_wrapper_end = ''
    if field.conditional?
      conditional_field = field.conditional_field
      if conditional_field
        values_json = field.conditional_values.to_json.gsub('"', '&quot;')
        conditional_wrapper_start = "          <div class=\"conditional-field\" data-depends-on=\"#{conditional_field.field_name}\" data-show-values=\"#{values_json}\" style=\"display: none;\">\n"
        conditional_wrapper_end = "          </div>\n"
        # For conditional fields, don't require them initially (JS will handle validation)
        required_logic = '' if field.required
      end
    end

    # Read-only handling: on the new view, both 'always' and 'initial' are readonly
    is_read_only = field.read_only_always? || field.read_only_initial?
    readonly_attr = is_read_only ? 'readonly: true' : nil

    # Generate conditional answer data attributes for the form-group div
    conditional_answer_attrs = build_conditional_answer_attrs(field)

    # Build attributes hash string
    attrs = ["class: \"form-control#{' field-readonly' if is_read_only}\""]
    attrs << required_logic if required_logic.present?
    attrs << disabled_attr if disabled_attr.present?
    attrs << readonly_attr if readonly_attr.present?
    # Add data attribute for dropdowns that have conditional dependencies
    attrs << "data: { conditional_trigger: '#{field.field_name}' }" if (field.dropdown? || field.choices_dropdown?) && conditional_dependents?(field)
    attrs_str = attrs.join(', ')

    # For select/dropdown fields, use disabled instead of readonly (readonly doesn't work on selects)
    select_attrs = attrs.reject { |a| a == 'readonly: true' }
    select_attrs << 'disabled: true' if is_read_only && disabled_attr.nil?
    select_attrs_str = select_attrs.join(', ')

    case field.field_type
    when 'text'
      html = ''
      html += "        <% #{editable_check} %>\n" if editable_check
      html += conditional_wrapper_start
      html += <<~HTML
        <div class="form-group flex-fill<%= #{editable_check ? "' field-restricted' unless field_#{field.id}_editable" : "''"} %>"#{conditional_answer_attrs}>
          <%= form.label :#{field.field_name}, "#{field.label}" %>
      HTML
      html += "            <small class=\"restriction-notice\">#{restriction_label}</small>\n" if restriction_label
      html += "            <%= form.text_field :#{field.field_name}, #{attrs_str} %>\n"
      html += "          </div>\n"
      html += conditional_wrapper_end
      html
    when 'text_box'
      html = ''
      html += "        <% #{editable_check} %>\n" if editable_check
      html += conditional_wrapper_start
      html += <<~HTML
        <div class="form-group flex-fill<%= #{editable_check ? "' field-restricted' unless field_#{field.id}_editable" : "''"} %>"#{conditional_answer_attrs}>
          <%= form.label :#{field.field_name}, "#{field.label}" %>
      HTML
      html += "            <small class=\"restriction-notice\">#{restriction_label}</small>\n" if restriction_label
      html += "            <%= form.text_area :#{field.field_name}, rows: #{field.rows}, #{attrs_str} %>\n"
      html += "          </div>\n"
      html += conditional_wrapper_end
      html
    when 'dropdown'
      if field.custom_lookup?
        options_expr = "FormLookup.options(#{field.id})"
      elsif field.data_source?
        options_expr = field.data_source_query_code
      else
        options = field.dropdown_values.map { |v| "'#{v}'" }.join(', ')
        options_expr = "[#{options}]"
      end
      html = ''
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
    when 'choices_dropdown'
      if field.custom_lookup?
        options_expr = "FormLookup.options(#{field.id})"
      elsif field.data_source?
        options_expr = field.data_source_query_code
      else
        options = field.dropdown_values.map { |v| "'#{v}'" }.join(', ')
        options_expr = "[#{options}]"
      end
      # Build merged data hash for choices_dropdown (avoid duplicate data: keys)
      edit_data_entries = ['choices_target: "select"', 'placeholder: "Select options..."']
      edit_data_entries << "conditional_trigger: '#{field.field_name}'" if conditional_dependents?(field)
      edit_choices_attrs = select_attrs.reject { |a| a.start_with?('data:') }
      edit_choices_attrs_str = edit_choices_attrs.join(', ')
      html = ''
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
      html += "                  { #{edit_choices_attrs_str}, multiple: true, data: { #{edit_data_entries.join(', ')} } } %>\n"
      html += "          </div>\n"
      html += conditional_wrapper_end
      html
    when 'date'
      html = ''
      html += "        <% #{editable_check} %>\n" if editable_check
      html += conditional_wrapper_start
      html += <<~HTML
        <div class="form-group flex-fill<%= #{editable_check ? "' field-restricted' unless field_#{field.id}_editable" : "''"} %>"#{conditional_answer_attrs}>
          <%= form.label :#{field.field_name}, "#{field.label}" %>
      HTML
      html += "            <small class=\"restriction-notice\">#{restriction_label}</small>\n" if restriction_label
      html += "            <%= form.date_field :#{field.field_name}, #{attrs_str} %>\n"
      html += "          </div>\n"
      html += conditional_wrapper_end
      html
    when 'date_time'
      html = ''
      html += "        <% #{editable_check} %>\n" if editable_check
      html += conditional_wrapper_start
      html += <<~HTML
        <div class="form-group flex-fill<%= #{editable_check ? "' field-restricted' unless field_#{field.id}_editable" : "''"} %>"#{conditional_answer_attrs}>
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
      phone_attrs = ["class: \"form-control#{' field-readonly' if is_read_only}\""]
      phone_attrs << required_logic if required_logic.present?
      phone_attrs << disabled_attr if disabled_attr.present?
      phone_attrs << readonly_attr if readonly_attr.present?
      phone_attrs << 'placeholder: "e.g. 555-555-5555"'
      phone_attrs << 'title: "Enter a 10-digit phone number like 555-555-5555"'
      phone_attrs << 'data: { controller: "phone", phone_target: "input", action: "input->phone#format paste->phone#format blur->phone#validate" }'
      phone_attrs << "\"aria-describedby\": \"#{phone_id}Help #{phone_id}Error\""
      phone_attrs << 'pattern: "\\\\d{3}-\\\\d{3}-\\\\d{4}"'
      phone_attrs << 'inputmode: "numeric"'
      phone_attrs << 'autocomplete: "tel"'
      phone_attrs_str = phone_attrs.join(",\n                  ")
      html = ''
      html += "        <% #{editable_check} %>\n" if editable_check
      html += conditional_wrapper_start
      html += <<~HTML
        <div class="form-group flex-fill<%= #{editable_check ? "' field-restricted' unless field_#{field.id}_editable" : "''"} %>"#{conditional_answer_attrs}>
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
      email_attrs = ["class: \"form-control#{' field-readonly' if is_read_only}\""]
      email_attrs << required_logic if required_logic.present?
      email_attrs << disabled_attr if disabled_attr.present?
      email_attrs << readonly_attr if readonly_attr.present?
      email_attrs << 'placeholder: "e.g. name@example.com"'
      email_attrs << 'autocomplete: "email"'
      email_attrs_str = email_attrs.join(', ')
      html = ''
      html += "        <% #{editable_check} %>\n" if editable_check
      html += conditional_wrapper_start
      html += <<~HTML
        <div class="form-group flex-fill<%= #{editable_check ? "' field-restricted' unless field_#{field.id}_editable" : "''"} %>"#{conditional_answer_attrs}>
          <%= form.label :#{field.field_name}, "#{field.label}" %>
      HTML
      html += "            <small class=\"restriction-notice\">#{restriction_label}</small>\n" if restriction_label
      html += "            <%= form.email_field :#{field.field_name}, #{email_attrs_str} %>\n"
      html += "          </div>\n"
      html += conditional_wrapper_end
      html
    when 'number'
      html = ''
      html += "        <% #{editable_check} %>\n" if editable_check
      html += conditional_wrapper_start
      html += <<~HTML
        <div class="form-group flex-fill<%= #{editable_check ? "' field-restricted' unless field_#{field.id}_editable" : "''"} %>"#{conditional_answer_attrs}>
          <%= form.label :#{field.field_name}, "#{field.label}" %>
      HTML
      html += "            <small class=\"restriction-notice\">#{restriction_label}</small>\n" if restriction_label
      html += "            <%= form.number_field :#{field.field_name}, #{attrs_str} %>\n"
      html += "          </div>\n"
      html += conditional_wrapper_end
      html
    when 'currency'
      currency_attrs = attrs.dup
      currency_attrs << 'step: "0.01"'
      currency_attrs << 'min: "0"'
      currency_attrs_str = currency_attrs.join(', ')
      html = ''
      html += "        <% #{editable_check} %>\n" if editable_check
      html += conditional_wrapper_start
      html += <<~HTML
        <div class="form-group flex-fill<%= #{editable_check ? "' field-restricted' unless field_#{field.id}_editable" : "''"} %>"#{conditional_answer_attrs}>
          <%= form.label :#{field.field_name}, "#{field.label}" %>
      HTML
      html += "            <small class=\"restriction-notice\">#{restriction_label}</small>\n" if restriction_label
      html += "            <div class=\"currency-input-wrapper\">\n"
      html += "              <span class=\"currency-prefix\">$</span>\n"
      html += "              <%= form.number_field :#{field.field_name}, #{currency_attrs_str} %>\n"
      html += "            </div>\n"
      html += "          </div>\n"
      html += conditional_wrapper_end
      html
    when 'yes_no'
      html = ''
      html += "        <% #{editable_check} %>\n" if editable_check
      html += conditional_wrapper_start
      html += <<~HTML
        <div class="form-group flex-fill<%= #{editable_check ? "' field-restricted' unless field_#{field.id}_editable" : "''"} %>"#{conditional_answer_attrs}>
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
      html = ''
      html += "        <% #{editable_check} %>\n" if editable_check
      html += conditional_wrapper_start
      html += <<~HTML
        <div class="form-group flex-fill<%= #{editable_check ? "' field-restricted' unless field_#{field.id}_editable" : "''"} %>"#{conditional_answer_attrs}>
          <%= form.label :#{field.field_name}, "#{field.label}" %>
      HTML
      html += "            <small class=\"restriction-notice\">#{restriction_label}</small>\n" if restriction_label
      html += "            <%= form.time_field :#{field.field_name}, #{attrs_str} %>\n"
      html += "          </div>\n"
      html += conditional_wrapper_end
      html
    when 'media_attachment'
      html = ''
      html += "        <% #{editable_check} %>\n" if editable_check
      html += conditional_wrapper_start
      html += <<~HTML
        <div class="form-group flex-fill<%= #{editable_check ? "' field-restricted' unless field_#{field.id}_editable" : "''"} %>" data-controller="file-preview" data-file-preview-max-value="10">
          <%= form.label :#{field.field_name}, "#{field.label}" %>
      HTML
      html += "            <small class=\"restriction-notice\">#{restriction_label}</small>\n" if restriction_label
      html += "            <%= form.file_field :#{field.field_name}, multiple: true, class: \"form-control\", direct_upload: true, accept: \"image/jpeg,image/png,image/gif,image/webp,image/heic,image/heif,application/pdf\""
      html += ', disabled: true' if disabled_attr.present?
      html += ", data: { file_preview_target: \"input\", action: \"change->file-preview#preview\" } %>\n"
      html += "            <small class=\"form-text text-muted\">You can select files multiple times — up to 10 total. <span data-file-preview-target=\"count\"></span></small>\n"
      html += "            <div data-file-preview-target=\"preview\" class=\"file-preview-grid\"></div>\n"
      html += "          </div>\n"
      html += conditional_wrapper_end
      html
    when 'information'
      html = ''
      html += conditional_wrapper_start
      html += generate_information_field_html(field)
      html += conditional_wrapper_end
      html
    end.then { |rendered| wrap_visibility(field, editable_check, rendered) }
  end

  def conditional_dependents?(field)
    field.form_template.form_fields.any? { |f| f.conditional_field_id == field.id }
  end

  # Generate the ERB markup for an "information" field — a button that opens
  # a modal with display-only text. When `acknowledgeable` is true, the user
  # must click "I Agree" before the form will allow submission. No DB column
  # is written; agreement is enforced entirely on the client.
  def generate_information_field_html(field)
    text_escaped = ERB::Util.html_escape(field.information_text.to_s).gsub("\r\n", "\n").gsub("\n", '&#10;')
    label_escaped = ERB::Util.html_escape(field.label.to_s)
    ack_value = field.acknowledgeable? ? 'true' : 'false'

    <<~HTML
      <div class="form-group flex-fill information-field"
           data-controller="information-field"
           data-information-field-acknowledgeable-value="#{ack_value}"
           data-information-field-label-value="#{label_escaped}"
           data-information-field-text-value="#{text_escaped}">
        <button type="button"
                class="btn information-trigger"
                data-action="click->information-field#open"
                data-information-field-target="trigger">
          #{label_escaped}#{' <span class="information-required-indicator">*</span>' if field.acknowledgeable?}
        </button>
        <span class="information-status" data-information-field-target="status"></span>
        <input type="hidden"
               data-information-field-target="acknowledgedInput"
               data-required-acknowledgement="#{ack_value}">
      </div>
    HTML
  end

  def generate_editable_check(field, form_template)
    expr = field_restriction_expression(field, form_template)
    expr ? "field_#{field.id}_editable = #{expr}" : nil
  end

  # Returns a Ruby expression (as a string) that evaluates to true when the
  # current user should see this page, or nil when the page is unconditionally
  # visible. A page is auto-gated when every custom field on it is
  # restrict_visibility? — in that case, the page is shown if the user
  # qualifies for at least one of those fields' restrictions (or is admin).
  # Pages 1 and 2 carry standard employee/agency sections and are never gated.
  def generate_page_visibility_check(form_template, page_num)
    return nil if page_num <= 2

    fields = form_template.form_fields.for_page(page_num).to_a
    return nil if fields.empty?
    return nil if fields.any? { |f| !f.restrict_visibility? }

    checks = fields.map { |f| field_restriction_expression(f, form_template) }.compact.uniq
    return nil if checks.empty?

    "(#{checks.join(' || ')} || system_admin?)"
  end

  # Emits ERB locals at the top of the generated form that hold per-page
  # visibility flags (used to wrap each page and to derive a progress-dot count
  # that matches the pages the current user can actually reach).
  def render_page_visibility_decls(page_visibility)
    lines = page_visibility.map { |n, expr| "        <% _page_#{n}_visible = #{expr || 'true'} %>\n" }
    flags = page_visibility.keys.map { |n| "_page_#{n}_visible" }.join(', ')
    lines << "        <% _visible_page_count = [#{flags}].count(true) %>\n"
    "#{lines.join}\n"
  end

  def field_restriction_expression(field, form_template)
    case field.restricted_to_type
    when 'employee'
      "(session.dig(:user, 'employee_id').to_s == '#{field.restricted_to_employee_id}')"
    when 'group'
      base = "@current_user_groups&.include?(#{field.restricted_to_group_id})"
      if field.org_filtered?
        level = field.restricted_to_org_filter_level
        "(#{base} && current_user_org_chain[:#{level}_id].to_s == @#{form_template.file_name}.#{level}.to_s)"
      else
        base
      end
    end
  end

  # When a restricted field is set to "Visible to: Only the filler", hide its
  # entire rendered block from non-fillers. system_admin? always sees through
  # the gate. The editable_check line must stay OUTSIDE the wrapper so the
  # field_X_editable variable is defined when the wrapper evaluates it.
  def wrap_visibility(field, editable_check, rendered)
    return rendered unless field.restrict_visibility? && editable_check

    editable_line = "        <% #{editable_check} %>\n"
    visibility_open = "        <% if field_#{field.id}_editable || system_admin? %>\n"
    visibility_close = "        <% end %>\n"

    if rendered.include?(editable_line)
      rendered.sub(editable_line, editable_line + visibility_open) + visibility_close
    else
      visibility_open + rendered + visibility_close
    end
  end
end
