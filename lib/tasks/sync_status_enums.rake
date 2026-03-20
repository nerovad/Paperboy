namespace :paperboy do
  desc "Reconstruct routing steps, statuses, fields, and model enums from generated files"
  task rebuild_form_templates: :environment do
    controller = FormTemplatesController.new
    # Standard fields on pages 1-2 that should NOT be treated as custom fields
    standard_fields = %w[employee_id name phone email agency division department unit]

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

      # =============================================
      # 1. Reconstruct routing steps from controller
      # =============================================
      if ft.routing_steps.empty? && controller_content.include?('Multi-step approval routing')
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
      end

      # =============================================
      # 2. Reconstruct statuses from model enum
      # =============================================
      if ft.statuses.empty? && model_content =~ /enum :status/
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

            ft.statuses.create!(
              name: key.humanize,
              key: key,
              category: category,
              position: index,
              is_initial: is_initial,
              is_end: is_end,
              auto_generated: is_auto
            )
            puts "    Status: #{key} (#{category}, #{is_auto ? 'auto' : 'user'})"
          end
        end
      end

      # =============================================
      # 3. Reconstruct form fields from generated view
      # =============================================
      if ft.form_fields.empty? && File.exist?(view_path)
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

          # Close conditional wrapper
          if current_conditional && line =~ /<\/div>\s*$/ && !line.include?('form-group')
            # This is tricky - we'll associate conditionals at field detection time
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
                         elsif field_context =~ /form\.datetime_local_field\s+:#{field_name}/
                           'date'
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

            # Extract dropdown values
            if field_type == 'dropdown'
              values_match = field_context.match(/options_for_select\(\[(.*?)\]\)/m)
              if values_match
                raw = values_match[1]
                options['values'] = raw.scan(/'([^']+)'/).flatten
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
      if ft.page_headers.blank? && File.exist?(view_path)
        view_content = File.read(view_path)
        headers = []
        view_content.scan(/<!--\s*Page (\d+): (.+?)\s*-->/).each do |num, header|
          page_num = num.to_i
          next if page_num <= 2 # Skip Employee Info and Agency Info
          headers << header.strip
        end

        if headers.any?
          ft.update_columns(page_headers: headers.to_json, page_count: headers.size + 2)
          puts "  Restored page headers: #{headers.join(', ')}"
        end
      end

      # =============================================
      # 5. Regenerate model with STATUS_LABELS
      # =============================================
      if ft.statuses.any?
        controller.send(:customize_generated_model, ft)
        puts "  Regenerated model enum + STATUS_LABELS"
      end
    end

    puts "\nDone!"
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
