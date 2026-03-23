namespace :paperboy do
  desc "Reconstruct routing steps, statuses, fields, and page headers from generated files"
  # Usage:
  #   rails paperboy:rebuild_form_templates           # only populate empty records
  #   FORCE=1 rails paperboy:rebuild_form_templates   # destroy and re-populate all records
  task rebuild_form_templates: :environment do
    force = ENV['FORCE'] == '1'
    # Standard fields on pages 1-2 that should NOT be treated as custom fields
    standard_fields = %w[employee_id name phone email agency division department unit]

    # Fix double-encoded JSON from prior runs (update_columns + .to_json bug)
    # The model's page_headers/inbox_buttons accessors now auto-unwrap strings,
    # so we can read the corrected value and re-save it to fix the DB permanently.
    puts "== Repairing double-encoded JSON fields =="
    FormTemplate.find_each do |ft|
      raw_headers = ft.read_attribute_before_type_cast('page_headers')
      raw_buttons = ft.read_attribute_before_type_cast('inbox_buttons')

      needs_fix = false

      # Check if raw DB value decodes to a string (double-encoded) rather than array/nil
      if raw_headers.present?
        begin
          decoded = JSON.parse(raw_headers)
          if decoded.is_a?(String)
            needs_fix = true
          end
        rescue; end
      end

      if raw_buttons.present?
        begin
          decoded = JSON.parse(raw_buttons)
          if decoded.is_a?(String)
            needs_fix = true
          end
        rescue; end
      end

      if needs_fix
        # Model accessors unwrap the double-encoding — write corrected values
        # directly to DB, bypassing validations that may fail on unrelated fields
        fixed_headers = ft.page_headers  # accessor auto-unwraps
        fixed_buttons = ft.inbox_buttons # accessor auto-unwraps
        ft.update_columns(
          page_headers: fixed_headers&.to_json,
          inbox_buttons: (fixed_buttons || []).to_json
        )
        puts "  Fixed double-encoded JSON on #{ft.name}"
      end
    end
    puts ""

    FormTemplate.find_each do |ft|
      puts "\n== #{ft.name} (#{ft.class_name}) =="

      controller_path = Rails.root.join("app/controllers/#{ft.plural_file_name}_controller.rb")
      model_path = Rails.root.join("app/models/#{ft.file_name}.rb")
      view_path = Rails.root.join("app/views/#{ft.plural_file_name}/new.html.erb")

      unless File.exist?(controller_path) && File.exist?(model_path)
        puts "  SKIP - missing model or controller files"
        next
      end

      controller_content = File.read(controller_path)
      model_content = File.read(model_path)

      # Parse STATUS_LABELS from model (used for proper status names)
      status_labels = {}
      labels_match = model_content.match(/STATUS_LABELS\s*=\s*\{(.*?)\}\.freeze/m)
      if labels_match
        labels_match[1].scan(/(\w+):\s*"([^"]+)"/).each { |k, v| status_labels[k] = v }
      end

      # =============================================
      # 1. Reconstruct routing steps from controller
      # =============================================
      if force || ft.routing_steps.empty?
        ft.routing_steps.destroy_all if force && ft.routing_steps.any?

        if controller_content.include?('Multi-step approval routing')
          step_count_match = controller_content.match(/Multi-step approval routing \((\d+) steps?\)/)
          if step_count_match
            puts "  Found #{step_count_match[1]}-step routing in controller"

            steps_parsed = []
            controller_content.scan(/# Step (\d+): (.+)/).each do |num, description|
              step_num = num.to_i
              next if steps_parsed.any? { |s| s[:step_number] == step_num }

              desc = description.strip
              if desc == 'supervisor'
                steps_parsed << { step_number: step_num, routing_type: 'supervisor', employee_id: nil }
              elsif desc == 'department head'
                steps_parsed << { step_number: step_num, routing_type: 'department_head', employee_id: nil }
              elsif desc =~ /employee #(\d+)/
                steps_parsed << { step_number: step_num, routing_type: 'employee', employee_id: $1.to_i }
              end
            end

            steps_parsed.each do |step_data|
              ft.routing_steps.create!(step_data)
              puts "    Step #{step_data[:step_number]}: #{step_data[:routing_type]}#{step_data[:employee_id] ? " (employee #{step_data[:employee_id]})" : ''}"
            end

            ft.update_columns(submission_type: 'approval') unless ft.submission_type == 'approval'
          end
        else
          # No routing comments found — set submission_type to database if not already set
          ft.update_columns(submission_type: 'database') if ft.submission_type.blank?
          puts "  No routing steps found — submission_type: #{ft.submission_type || 'database'}"
        end
      end

      # =============================================
      # 2. Reconstruct statuses from model enum
      # =============================================
      if (force || ft.statuses.empty?) && model_content =~ /enum :status/
        ft.statuses.destroy_all if force && ft.statuses.any?

        puts "  Reconstructing statuses from model enum..."

        enum_match = model_content.match(/enum :status,\s*\{(.*?)\}/m)
        if enum_match
          entries = enum_match[1].scan(/(\w+):\s*(\d+)/)

          categories = {}
          cat_match = model_content.match(/STATUS_CATEGORIES\s*=\s*\{(.*?)\}\.freeze/m)
          if cat_match
            cat_match[1].scan(/(\w+):\s*:(\w+)/).each { |k, v| categories[k] = v }
          end

          default_match = model_content.match(/default:\s*:(\w+)/)
          default_key = default_match ? default_match[1] : nil

          entries.each_with_index do |(key, _value), index|
            category = categories[key] || guess_category(key)
            is_initial = (key == default_key) || (index == 0 && default_key.nil?)
            is_end = %w[approved denied cancelled resolved].include?(key)
            is_auto = key.match?(/^step_\d+_(pending|approved)$/)

            # Use STATUS_LABELS for proper name, fall back to humanize
            status_name = status_labels[key] || key.humanize.gsub(/\b\w/) { |m| m.upcase }

            ft.statuses.create!(
              name: status_name,
              key: key,
              category: category,
              position: index,
              is_initial: is_initial,
              is_end: is_end,
              auto_generated: is_auto
            )
            puts "    Status: #{status_name} [#{key}] (#{category}, #{is_auto ? 'auto' : 'user'})"
          end
        end
      end

      # =============================================
      # 3. Reconstruct form fields from generated view
      # =============================================
      if (force || ft.form_fields.empty?) && File.exist?(view_path)
        ft.form_fields.destroy_all if force && ft.form_fields.any?

        puts "  Reconstructing fields from generated view..."

        view_content = File.read(view_path)

        current_page = 0
        position = 0
        # Track conditional field context
        current_conditional = nil

        view_content.each_line do |line|
          # Track page number from comments like "<!-- Page 3: Services -->"
          if line =~ /<!--\s*Page (\d+):/
            current_page = $1.to_i
          end

          # Skip standard fields on pages 1-2
          next if current_page <= 2

          # Detect conditional wrapper
          if line =~ /class="conditional-field"\s+data-depends-on="(\w+)"\s+data-show-values="([^"]+)"/
            trigger_field = $1
            raw_values = $2.gsub('&quot;', '"')
            begin
              current_conditional = { field: trigger_field, values: JSON.parse(raw_values) }
            rescue
              current_conditional = nil
            end
          end

          # Detect field: form.label :field_name, "Label"
          if line =~ /form\.label\s+:(\w+),\s*"([^"]+)"/
            field_name = $1
            label = $2

            next if standard_fields.include?(field_name)

            # Look ahead in surrounding lines for field type
            field_context = view_content[view_content.index(line), 500] || ''

            field_type = if field_context =~ /form\.text_area\s+:#{field_name}/
                           'text_box'
                         elsif field_context =~ /form\.select\s+:#{field_name}/
                           'dropdown'
                         elsif field_context =~ /form\.datetime_local_field\s+:#{field_name}|form\.date_field\s+:#{field_name}/
                           'date'
                         elsif field_context =~ /form\.time_field\s+:#{field_name}/
                           'time'
                         elsif field_context =~ /form\.number_field\s+:#{field_name}/
                           'number'
                         elsif field_context =~ /form\.email_field\s+:#{field_name}/
                           'email'
                         elsif field_context =~ /form\.telephone_field\s+:#{field_name}|form\.phone_field\s+:#{field_name}|data-controller="phone"/
                           'phone'
                         elsif field_context =~ /options_for_select\(\[.*?'Yes'.*?'No'/m
                           'yes_no'
                         else
                           'text'
                         end

            required = !!(field_context =~ /required:\s*true/)

            options = {}

            # Extract rows for text_box
            if field_type == 'text_box'
              rows_match = field_context.match(/rows:\s*(\d+)/)
              options['rows'] = rows_match[1].to_i if rows_match
            end

            # Extract dropdown values (static options only)
            if field_type == 'dropdown'
              values_match = field_context.match(/options_for_select\(\[\s*(.*?)\s*\]\)/m)
              if values_match
                raw = values_match[1]
                # Match both single-quoted and double-quoted strings
                options['values'] = raw.scan(/['"]([^'"]+)['"]/).flatten
              end
            end

            field = ft.form_fields.create!(
              label: label,
              field_type: field_type,
              page_number: current_page,
              position: position,
              required: required,
              options: options.presence || {},
              restricted_to_type: 'none'
            )
            position += 1

            # Apply conditional logic if we're inside a conditional wrapper
            if current_conditional
              # Find the trigger field by name
              trigger = ft.form_fields.find_by("label LIKE ?", "%#{current_conditional[:field].humanize}%")
              if trigger
                field.update!(
                  conditional_field_id: trigger.id,
                  conditional_values: current_conditional[:values]
                )
                puts "    Field: #{label} (#{field_type}, page #{current_page}, conditional on #{current_conditional[:field]})"
              else
                puts "    Field: #{label} (#{field_type}, page #{current_page}, conditional ref unresolved: #{current_conditional[:field]})"
              end
              current_conditional = nil
            else
              puts "    Field: #{label} (#{field_type}, page #{current_page}#{required ? ', required' : ''})"
            end
          end
        end
      end

      # =============================================
      # 4. Reconstruct page_headers from view
      # =============================================
      if (force || ft.page_headers.blank?) && File.exist?(view_path)
        view_content ||= File.read(view_path)
        headers = []
        view_content.scan(/<!--\s*Page (\d+): (.+?)\s*-->/).each do |num, header|
          page_num = num.to_i
          next if page_num <= 2 # Skip Employee Info and Agency Info
          headers << header.strip
        end

        if headers.any?
          ft.update_columns(page_headers: headers.to_json, page_count: headers.size + 2)
          puts "  Restored page headers: #{headers.join(', ')} (#{headers.size + 2} pages)"
        elsif force
          # No page headers found in view — clear any corrupted data
          ft.update_columns(page_headers: nil) unless ft.page_headers.nil?
          puts "  No page headers found in view — cleared"
        end
      end

      # =============================================
      # 5. Set inbox_buttons based on controller actions
      # =============================================
      if force || (ft.inbox_buttons.blank? || ft.inbox_buttons.empty?)
        buttons = []

        # Detect available actions from the controller file
        if File.exist?(controller_path)
          ctrl = controller_content

          # view_pdf: controller has a pdf action
          buttons << 'view_pdf' if ctrl =~ /def pdf\b/

          # edit: controller has an edit action
          buttons << 'edit' if ctrl =~ /def edit\b/

          # approve: controller has an approve action
          buttons << 'approve' if ctrl =~ /def approve\b/

          # deny: controller has a deny action
          buttons << 'deny' if ctrl =~ /def deny\b/

          # status_dropdown: controller has an update_status action
          buttons << 'status_dropdown' if ctrl =~ /def update_status\b/

          # reassign: always available (handled by task_reassignments_controller)
          buttons << 'reassign'

          # take_back: always available (handled by task_reassignments_controller)
          buttons << 'take_back'
        end

        # Fallback for basic forms with no controller actions
        buttons = %w[view_pdf] if buttons.empty?

        ft.update_columns(inbox_buttons: buttons.to_json)
        puts "  Set inbox_buttons: #{buttons.join(', ')}"
      end

      puts "  Done (#{ft.statuses.count} statuses, #{ft.routing_steps.count} routing steps, #{ft.form_fields.count} fields)"
    end

    puts "\nDone! Run with FORCE=1 to re-populate all records from generated files."
  end
end

def guess_category(key)
  case key
  when /submitted|pending|in_progress/
    'pending'
  when /approved|resolved|completed/
    'approved'
  when /denied|rejected/
    'denied'
  when /cancelled/
    'cancelled'
  when /scheduled/
    'scheduled'
  else
    'in_review'
  end
end
