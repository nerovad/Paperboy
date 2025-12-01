# lib/tasks/reports.rake
namespace :reports do
  desc "Scaffold a new Prawn/YAML/Sidekiq-based report. Usage: rake reports:new[report_name]"
  task :new, [:name] => :environment do |_t, args|
    unless args[:name]
      puts "Usage: rake reports:new[report_name]"
      exit 1
    end

    name       = args[:name].underscore
    class_name = args[:name].camelize
    base_path  = Rails.root.join("app/reports/#{name}")

    # ----------------------------------------------------------------------
    # Create directories
    # ----------------------------------------------------------------------
    FileUtils.mkdir_p base_path
    FileUtils.mkdir_p Rails.root.join("config/reports")
    FileUtils.mkdir_p Rails.root.join("app/pdfs/#{name}")

    # ----------------------------------------------------------------------
    # Create Service
    # ----------------------------------------------------------------------
    service_file = base_path.join("#{name}_service.rb")
    unless File.exist?(service_file)
      File.write(service_file, <<~RUBY)
        module Reports
          module #{class_name}
            class #{class_name}Service < Reports::Base::ReportService
              def stored_proc
                # TODO: insert stored procedure name
                "dbo.StoredProcedureName"
              end

              def report_name
                "#{name}"
              end
            end
          end
        end
      RUBY

      puts "✓ Created service: #{service_file}"
    else
      puts "⚠ Service exists: #{service_file}"
    end

    # ----------------------------------------------------------------------
    # Create Sidekiq Worker
    # ----------------------------------------------------------------------
    worker_file = Rails.root.join("app/jobs/#{name}_job.rb")
    unless File.exist?(worker_file)
      File.write(worker_file, <<~RUBY)
        class #{class_name}Job
          include Sidekiq::Job

          def perform(params)
            Reports::#{class_name}::#{class_name}Service.new(params.symbolize_keys).call
          end
        end
      RUBY

      puts "✓ Created worker: #{worker_file}"
    else
      puts "⚠ Worker exists: #{worker_file}"
    end

    # ----------------------------------------------------------------------
    # Create YAML mapping
    # ----------------------------------------------------------------------
    yaml_file = Rails.root.join("config/reports/#{name}.yml")
    unless File.exist?(yaml_file)
      File.write(yaml_file, <<~YAML)
        fields:
          sample_field:
            x: 100
            y: 700
      YAML

      puts "✓ Created YAML mapping: #{yaml_file}"
    else
      puts "⚠ YAML exists: #{yaml_file}"
    end

    # ----------------------------------------------------------------------
    # Create placeholder template PDF
    # ----------------------------------------------------------------------
    template_path = Rails.root.join("app/pdfs/#{name}/template.pdf")
    unless File.exist?(template_path)
      require "prawn"
      Prawn::Document.generate(template_path.to_s) do
        text "#{class_name} Template (replace with Creative Services PDF)", size: 18
      end

      puts "✓ Created placeholder template PDF: #{template_path}"
    else
      puts "⚠ Template PDF exists: #{template_path}"
    end

    puts "\n🎉 Report scaffold '#{name}' created successfully.\n"
  end
end
