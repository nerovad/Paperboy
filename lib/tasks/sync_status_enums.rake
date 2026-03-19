namespace :paperboy do
  desc "Sync statuses and regenerate model enums for all approval forms with routing steps"
  task sync_status_enums: :environment do
    controller = FormTemplatesController.new

    FormTemplate.where(submission_type: 'approval').find_each do |ft|
      next unless ft.routing_steps.any?

      puts "Processing: #{ft.name} (#{ft.class_name})"

      # Only sync if there are no auto_generated statuses yet (first run)
      if ft.statuses.auto_generated.none?
        # Auto-generate step statuses from existing routing steps
        steps = ft.routing_steps.ordered.to_a
        position = ft.statuses.maximum(:position).to_i + 1

        steps.each_with_index do |step, index|
          step_num = index + 1

          unless ft.statuses.exists?(key: "step_#{step_num}_pending")
            ft.statuses.create!(
              name: step.pending_display_name,
              key: "step_#{step_num}_pending",
              category: 'in_review',
              position: position,
              is_initial: false, is_end: false, auto_generated: true
            )
            position += 1
          end

          unless step_num == steps.count || ft.statuses.exists?(key: "step_#{step_num}_approved")
            ft.statuses.create!(
              name: step.approved_display_name,
              key: "step_#{step_num}_approved",
              category: 'in_review',
              position: position,
              is_initial: false, is_end: false, auto_generated: true
            )
            position += 1
          end
        end
      end

      # Regenerate model enum
      controller.send(:customize_generated_model, ft)
      puts "  -> Updated model: app/models/#{ft.file_name}.rb"
    end

    puts "Done!"
  end
end
