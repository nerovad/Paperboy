# lib/tasks/reports.rake
# {{{ task: new

namespace :reports do
  desc "Scaffold a new Prawn/YAML/Sidekiq-based report. Usage: rake reports:new[report_name]"
  task :new, [ :name ] => :environment do |_t, args|
    unless args[:name]
      puts "Usage: rake reports:new[report_name]"
      exit 1
    end

    name       = args[:name].underscore
    class_name = args[:name].camelize
    base_path  = Rails.root.join("app/reports/#{name}")

    # --------------------------------------------------------------------------
    # Create directories
    # --------------------------------------------------------------------------
    FileUtils.mkdir_p base_path
    FileUtils.mkdir_p Rails.root.join("config/reports")
    FileUtils.mkdir_p Rails.root.join("app/pdfs/#{name}")

    # --------------------------------------------------------------------------
    # Create Service
    # --------------------------------------------------------------------------
    service_file = base_path.join("#{name}_service.rb")
    unless File.exist?(service_file)
      File.write(service_file, <<~RUBY)
        module Reports
          module #{class_name}
            class #{class_name}Service < Reports::Base::ReportService

              def stored_proc
                "GSABSS.dbo.Paperboy_Reports_Scaffolding"
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

    # --------------------------------------------------------------------------
    # Create Sidekiq Worker
    # --------------------------------------------------------------------------
    worker_file = Rails.root.join("app/jobs/#{name}_job.rb")
    unless File.exist?(worker_file)
      File.write(worker_file, <<~RUBY)
        class #{class_name}Job
          include Sidekiq::Job

          def perform(params)
            Reports::#{class_name}::#{class_name}Service
              .new(params.symbolize_keys)
              .call
          end
        end
      RUBY

      puts "✓ Created worker: #{worker_file}"
    else
      puts "⚠ Worker exists: #{worker_file}"
    end

    # --------------------------------------------------------------------------
    # Create YAML mapping
    # --------------------------------------------------------------------------
    yaml_file = Rails.root.join("config/reports/#{name}.yml")
    unless File.exist?(yaml_file)
      File.write(yaml_file, <<~YAML)
        fields:
          cunit:
            x: 100
            y: 720
          posting_ref:
            x: 200
            y: 720
          service:
            x: 100
            y: 700
          date:
            x: 100
            y: 680
          doc_nmbr:
            x: 100
            y: 660
          description:
            x: 100
            y: 640
          quantity:
            x: 400
            y: 680
          rate:
            x: 450
            y: 680
          cost:
            x: 500
            y: 680
      YAML

      puts "✓ Created YAML mapping: #{yaml_file}"
    else
      puts "⚠ YAML exists: #{yaml_file}"
    end

    # --------------------------------------------------------------------------
    # Create placeholder template PDF
    # --------------------------------------------------------------------------
    template_path = Rails.root.join("app/pdfs/#{name}/template.pdf")
    unless File.exist?(template_path)
      require "prawn"
      Prawn::Document.generate(template_path.to_s) do
        text "#{class_name} Template (replace with Creative Services PDF)", size: 18
        stroke_horizontal_rule
        move_down 10
        text "Fields expected from SQL:", style: :bold
        text "- CUNIT"
        text "- POSTING_REF"
        text "- SERVICE"
        text "- DATE"
        text "- DOC_NMBR"
        text "- DESCRIPTION"
        text "- OTHER1, OTHER2, OTHER3"
        text "- QUANTITY, RATE, COST"
      end

      puts "✓ Created placeholder template PDF: #{template_path}"
    else
      puts "⚠ Template PDF exists: #{template_path}"
    end

    puts "\n🎉 Report scaffold '#{name}' created successfully.\n"
  end
end

# -------------------------------------------------------------------------- }}}
# {{{ task: destroy

namespace :reports do
  desc "Destroy a Prawn/YAML/Sidekiq-based report scaffold. Usage: rake reports:destroy[report_name]"
  task :destroy, [ :name ] => :environment do |_t, args|
    unless args[:name]
      puts "Usage: rake reports:destroy[report_name]"
      exit 1
    end

    name = args[:name].underscore

    paths = {
      service_dir: Rails.root.join("app/reports/#{name}"),
      worker_file: Rails.root.join("app/jobs/#{name}_job.rb"),
      yaml_file:   Rails.root.join("config/reports/#{name}.yml"),
      pdf_dir:     Rails.root.join("app/pdfs/#{name}")
    }

    puts "\nThe following items will be removed:\n\n"
    paths.each do |_key, path|
      exists = File.exist?(path) || Dir.exist?(path)
      puts "  #{exists ? '✓' : '✗'} #{path}"
    end

    puts "\n⚠️ This operation is irreversible."

    unless ENV["FORCE"]
      print "\nType 'yes' to continue: "
      confirm = STDIN.gets.strip
      unless confirm == "yes"
        puts "✗ Aborted."
        exit 1
      end
    end

    paths.each do |_key, path|
      if File.file?(path)
        File.delete(path)
        puts "✓ Deleted file: #{path}"
      elsif Dir.exist?(path)
        FileUtils.rm_rf(path)
        puts "✓ Deleted directory: #{path}"
      else
        puts "✗ Not found: #{path}"
      end
    end

    puts "\n🎉 Report '#{name}' successfully destroyed.\n"
  end
end

# -------------------------------------------------------------------------- }}}
# {{{ task: run

namespace :reports do
  desc "Run a report immediately (no Sidekiq). Usage: rake reports:run[name,sDate,eDate]"
  task :run, [ :name, :sDate, :eDate ] => :environment do |_t, args|
    unless args[:name] && args[:sDate] && args[:eDate]
      puts "Usage: rake reports:run[report_name,YYYY-MM-DD,YYYY-MM-DD]"
      exit 1
    end

    report_name = args[:name].underscore
    class_name  = args[:name].camelize

    service_path =
      Rails.root.join("app/reports/#{report_name}/#{report_name}_service.rb")

    unless File.exist?(service_path)
      puts "✗ ERROR: Service file not found:"
      puts "  #{service_path}"
      exit 1
    end

    base_dir = Rails.root.join("app/reports/base")
    Dir[base_dir.join("*.rb")].sort.each do |file|
      require file
    end
    require service_path.to_s

    begin
      service_class =
        Reports.const_get(class_name).const_get("#{class_name}Service")
    rescue NameError
      puts "✗ ERROR: Unable to resolve service class:"
      puts "  Reports::#{class_name}::#{class_name}Service"
      exit 1
    end

    params = {
      sDate: args[:sDate],
      eDate: args[:eDate]
    }

    puts "\n▶ Running report: #{report_name}"
    puts "  sDate = #{args[:sDate]}"
    puts "  eDate = #{args[:eDate]}"
    puts "  Service = #{service_class.name}\n\n"

    begin
      output_path = service_class.new(params).call
    rescue => e
      puts "✗ ERROR during report generation:"
      puts e.message
      puts e.backtrace.join("\n")
      exit 1
    end

    puts "✓ Report generated successfully!"
    puts "→ Output PDF: #{output_path}\n\n"
  end
end

# -------------------------------------------------------------------------- }}}
# {{{ task: doctor

namespace :reports do
  desc "Diagnose Zeitwerk/autoload problems for the Reports subsystem"
  task doctor: :environment do
    puts "\n=== 📋 REPORTS DOCTOR ===\n\n"

    puts "➡ Autoload paths:"
    ActiveSupport::Dependencies.autoload_paths.each do |path|
      puts "   - #{path}"
    end

    puts "\n➡ Eager load paths:"
    Rails.application.config.eager_load_paths.each do |path|
      puts "   - #{path}"
    end

    reports_path = Rails.root.join("app/reports").to_s

    puts "\n➡ Checking if app/reports is autoloaded:"
    puts ActiveSupport::Dependencies.autoload_paths.include?(reports_path) ?
         "   ✓ app/reports IS in autoload paths" :
         "   ✗ app/reports is NOT in autoload paths"

    puts "\n➡ Checking if app/reports is eager loaded:"
    puts Rails.application.config.eager_load_paths.include?(reports_path) ?
         "   ✓ app/reports IS in eager load paths" :
         "   ✗ app/reports is NOT in eager load paths"

    puts "\n➡ Checking namespace constants:\n"

    begin
      Reports
      puts "   ✓ Reports constant exists"
    rescue NameError
      puts "   ✗ Reports constant missing"
    end

    begin
      Reports::Base
      puts "   ✓ Reports::Base constant exists"
    rescue NameError
      puts "   ✗ Reports::Base constant missing"
    end

    base_dir = Rails.root.join("app/reports/base")
    puts "\n➡ Testing base class loadability:"
    Dir[base_dir.join("*.rb")].each do |file|
      print "   Loading #{File.basename(file)} ... "
      begin
        require file
        puts "OK"
      rescue => e
        puts "FAILED (#{e.class}: #{e.message})"
      end
    end

    puts "\n➡ Testing base class constants:"
    {
      ReportService: "Reports::Base::ReportService",
      PdfRenderer:   "Reports::Base::PdfRenderer",
      SqlProvider:  "Reports::Base::SqlProvider",
      TemplateLoader: "Reports::Base::TemplateLoader",
      YamlLoader:   "Reports::Base::YamlLoader"
    }.each do |_short, full|
      print "   #{full} ... "
      begin
        full.constantize
        puts "OK"
      rescue => e
        puts "FAILED (#{e.class})"
      end
    end

    puts "\n=== 🩺 REPORTS DOCTOR COMPLETE ===\n\n"
  end
end

# -------------------------------------------------------------------------- }}}
