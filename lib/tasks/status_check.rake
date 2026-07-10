namespace :status do
  desc "Verify each TrackableStatus model's status enum matches its form_template_statuses keys"
  task check: :environment do
    Rails.application.eager_load!

    problems = []
    models = ApplicationRecord.descendants.select do |m|
      m.include?(TrackableStatus) && m.table_exists?
    end

    models.sort_by(&:name).each do |model|
      template = FormTemplate.find_by(class_name: model.name)
      next unless template

      central = template.statuses.pluck(:key).map(&:to_s).sort
      next if central.empty? # database-type forms with no workflow statuses

      enum_keys = (model.defined_enums['status']&.keys || []).sort
      column    = model.columns_hash['status']

      issues = []
      issues << 'status column is still INTEGER-backed (expected string keys)' if column&.type == :integer
      if enum_keys.empty?
        issues << "model defines no status enum (central keys: #{central.join(', ')})"
      elsif enum_keys != central
        issues << "enum #{enum_keys.inspect} != central #{central.inspect}"
      end

      if issues.empty?
        puts "  OK   #{model.name} (#{enum_keys.join(', ')})"
      else
        problems << "#{model.name}: #{issues.join('; ')}"
      end
    end

    if problems.any?
      warn "\nStatus inconsistencies:"
      problems.each { |p| warn "  x #{p}" }
      abort "status:check failed for #{problems.size} model(s)"
    else
      puts "\nAll TrackableStatus models are consistent with form_template_statuses."
    end
  end
end
