# lib/tasks/reports.rake
# {{{ task: new

namespace :reports do
  # {{{ task new definition

  desc "Scaffold a new Prawn/YAML/Sidekiq-based report. Usage: rake reports:new[report_name]"
  task :new, [ :name ] => :environment do |_t, args|
    unless args[:name]
      puts "Usage: rake reports:new[report_name]"
      exit 1
    end

    name       = args[:name].underscore
    class_name = args[:name].camelize
    base_path  = Rails.root.join("app/reports/#{name}")

    # ---------------------------------------------------------------------- }}}
    # {{{ Create directories


    FileUtils.mkdir_p base_path
    FileUtils.mkdir_p Rails.root.join("config/reports")
    FileUtils.mkdir_p Rails.root.join("tmp/reports")
    FileUtils.mkdir_p Rails.root.join("app/pdfs/#{name}")

    # ---------------------------------------------------------------------- }}}
    # {{{ Copy base PDF template
    #     TODO: placehoder for template overlay logic. :wall
    #

    template_src = Rails.root.join("app/pdfs/templates/template.pdf")
    template_dst = Rails.root.join("app/pdfs/#{name}/#{name}.pdf")

    if File.exist?(template_src)
      FileUtils.cp(template_src, template_dst)
      puts "Copied template PDF → #{template_dst}"
    else
      puts "WARNING: template.pdf not found at #{template_src}"
    end

    # ---------------------------------------------------------------------- }}}
    # {{{ Create Service

    service_file = base_path.join("#{name}_service.rb")
    unless File.exist?(service_file)
      File.write(service_file, <<~RUBY)
        module #{class_name}
          class #{class_name}Service < Base::ReportService

            # TODO: Stwp in the correct report-specific stored procedure.
            def stored_proc
              "GSABSS.dbo.Paperboy_Reports_Scaffolding"
            end

            def report_name
              "#{name}"
            end

          end
        end
      RUBY

      puts "Created service: #{service_file}"
    else
      puts "Service exists: #{service_file}"
    end

    # ---------------------------------------------------------------------- }}}
    # {{{ Create Sidekiq Worker

    worker_file = Rails.root.join("app/jobs/#{name}_job.rb")
    unless File.exist?(worker_file)
      File.write(worker_file, <<~RUBY)
        class #{class_name}Job
          include Sidekiq::Job

          def perform(params)
            #{class_name}::#{class_name}Service
              .new(params.symbolize_keys)
              .call
          end
        end
      RUBY

      puts "Created worker: #{worker_file}"
    else
      puts "Worker exists: #{worker_file}"
    end

    # ---------------------------------------------------------------------- }}}
    # {{{ Create YAML mapping
    #

    yaml_file = Rails.root.join("config/reports/#{name}.yml")
    unless File.exist?(yaml_file)
      File.write(yaml_file, <<~YAML)
      # TODO: Update fields and x,y coorrdinates to match the report-specific stored procedue.
        fields:
          cunit:
            x: 135
            y: 695

          posting_ref:
            x: 135
            y: 675

          service:
            x: 135
            y: 655

          date:
            x: 135
            y: 635

          doc_nmbr:
            x: 135
            y: 615

          description:
            x: 135
            y: 595

          other1:
            x: 135
            y: 575

          other3:
            x: 135
            y: 555

          other2:
            x: 135
            y: 535

          quantity:
            x: 135
            y: 515

          rate:
            x: 135
            y: 495

          cost:
            x: 135
            y: 475
      YAML

      puts "Created YAML mapping: #{yaml_file}"
    else
      puts "YAML exists: #{yaml_file}"
    end

    # ---------------------------------------------------------------------- }}}
    # {{{ Create Controller

    controller_file =
      Rails.root.join("app/controllers/#{name}_reports_controller.rb")

    unless File.exist?(controller_file)
      File.write(controller_file, <<~RUBY)
        class #{class_name}ReportsController < ApplicationController
          def show
            @report_name = "#{name}"
          end

          def run
            #{class_name}Job.perform_async(
              sDate: params[:sDate],
              eDate: params[:eDate]
            )

            redirect_to root_path,
              notice: "#{class_name} report submitted for generation."
          end
        end
      RUBY

      puts "Created controller: #{controller_file}"
    end

    # ---------------------------------------------------------------------- }}}
    # {{{ Create View

    view_dir = Rails.root.join("app/views/#{name}_reports")
    FileUtils.mkdir_p(view_dir)

    view_file = view_dir.join("show.html.erb")

    unless File.exist?(view_file)
      File.write(view_file, <<~ERB)
        <h2>Generate #{class_name} Report</h2>

        <%= form_with url: #{name}_reports_run_path, method: :post do %>
          <div>
            <label>Start Date</label>
            <%= date_field_tag :sDate, nil, required: true %>
          </div>

          <div>
            <label>End Date</label>
            <%= date_field_tag :eDate, nil, required: true %>
          </div>

          <%= submit_tag "Generate Report" %>
        <% end %>
      ERB

      puts "Created view: #{view_file}"
    end

    # ---------------------------------------------------------------------- }}}
    # {{{ Create Renderer

    renderer_path =
      Rails.root.join("app/pdfs/#{name}/#{name}_renderer.rb")

    unless File.exist?(renderer_path)
      File.write(renderer_path, <<~RUBY)
        # app/pdfs/#{name}/#{name}_renderer.rb
        #
        # Developer-editable Prawn renderer.
        #
        # Receives:
        #   - pdf      Prawn::Document (already initialized with template + margin)
        #   - data     Array<Hash> (one hash per SQL row)
        #   - mapping  YAML field coordinates
        #   - template Path to PDF template (String)
        #
        # Contract:
        #   - One SQL row = one PDF page
        #   - Absolute coordinates assume margin: 0

        # TODO: Update renderer to match the report-specific stored procedue.

        module #{class_name}
          class Renderer
            def initialize(pdf:, data:, mapping:, template:)
              @pdf      = pdf
              @data     = data
              @mapping  = mapping
              @template = template.to_s
            end

            def render
              if @data.empty?
                @pdf.start_new_page
                @pdf.text "No data returned from stored procedure.", style: :bold
                return
              end

              @data.each do |row|
                @pdf.start_new_page

                logo_path = Rails.root.join("app/assets/images/report_logo.png")
                if File.exist?(logo_path)
                  @pdf.image(logo_path.to_s, at: [38, 780], width: 600)
                else
                  @pdf.text_box("MISSING LOGO", at: [38, 780], width: 200, height: 20)
                end

                @mapping.each do |field, coords|
                  value = row[field.to_s] || ""

                  x = coords["x"].to_i
                  y = coords["y"].to_i

                  @pdf.text_box(
                    "\#{field.to_s.upcase}:",
                    at: [x - 90, y],
                    width: 90,
                    height: 20,
                    overflow: :truncate,
                    disable_wrap: true
                  )

                  @pdf.text_box(
                    value.to_s,
                    at: [x, y],
                    width: 200,
                    height: 20,
                    overflow: :truncate,
                    disable_wrap: true
                  )
                end
              end

              @pdf.number_pages(
                "<page> of <total>",
                at: [500, 20],
                width: 100,
                align: :right
              )
            end

          end
        end
      RUBY

      puts "Created renderer: #{renderer_path}"
    else
      puts "Renderer exists: #{renderer_path}"
    end


    # ---------------------------------------------------------------------- }}}
    # {{{ Patch routes.rb

    routes_file = Rails.root.join("config/routes.rb")

    route_block = <<~RUBY

      # #{class_name} report
      get  "/reports/#{name}",     to: "#{name}_reports#show", as: "#{name}_reports"
      post "/reports/#{name}/run", to: "#{name}_reports#run",  as: "#{name}_reports_run"
    RUBY

    unless File.read(routes_file).include?("reports/#{name}")
      File.open(routes_file, "a") { |f| f.write(route_block) }
      puts "Routes added for #{name}"
    end

    # ---------------------------------------------------------------------- }}}
    puts "\nReport scaffold '#{name}' created successfully.\n"
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
      service_dir:  Rails.root.join("app/reports/#{name}"),
      worker_file:  Rails.root.join("app/jobs/#{name}_job.rb"),
      yaml_file:    Rails.root.join("config/reports/#{name}.yml"),
      pdf_dir:      Rails.root.join("app/pdfs/#{name}"),
      controller:   Rails.root.join("app/controllers/#{name}_reports_controller.rb"),
      view_dir:     Rails.root.join("app/views/#{name}_reports")
    }

    puts "\nThe following items will be removed:\n\n"
    paths.each do |_key, path|
      exists = File.exist?(path) || Dir.exist?(path)
      puts "  #{exists ? '✓' : '✗'} #{path}"
    end

    puts "\nThis operation is irreversible."

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
        puts "Deleted file: #{path}"
      elsif Dir.exist?(path)
        FileUtils.rm_rf(path)
        puts "Deleted directory: #{path}"
      else
        puts "Not found: #{path}"
      end
    end
    puts "\nReport '#{name}' successfully destroyed.\n"
    puts "\nManual step required:"
    puts "  Remove routes for '#{name}' from config/routes.rb if present."
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
      puts "ERROR: Service file not found:"
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
        Object.const_get(class_name).const_get("#{class_name}Service")
    rescue NameError
      puts "ERROR: Unable to resolve service class:"
      puts "#{class_name}::#{class_name}Service"
      exit 1
    end

    params = {
      sDate: args[:sDate],
      eDate: args[:eDate]
    }

    puts "\nRunning report: #{report_name}"
    puts "sDate = #{args[:sDate]}"
    puts "eDate = #{args[:eDate]}"
    puts "Service = #{service_class.name}\n\n"

    begin
      output_path = service_class.new(params).call
    rescue => e
      puts "ERROR during report generation:"
      puts e.message
      puts e.backtrace.join("\n")
      exit 1
    end

    puts "Report generated successfully!"
    puts "Output PDF: #{output_path}\n\n"
  end
end

# -------------------------------------------------------------------------- }}}
# {{{ task: doctor

namespace :reports do
  desc "Diagnose Zeitwerk/autoload problems for the Reports subsystem"
  task doctor: :environment do
    puts "\n=== REPORTS DOCTOR ===\n\n"

    puts "Autoload paths:"
    ActiveSupport::Dependencies.autoload_paths.each do |path|
      puts "   - #{path}"
    end

    puts "\nEager load paths:"
    Rails.application.config.eager_load_paths.each do |path|
      puts "   - #{path}"
    end

    reports_path = Rails.root.join("app/reports").to_s

    puts "\nChecking if app/reports is autoloaded:"
    puts ActiveSupport::Dependencies.autoload_paths.include?(reports_path) ?
         "  app/reports IS in autoload paths" :
         "  app/reports is NOT in autoload paths"

    puts "\nChecking if app/reports is eager loaded:"
    puts Rails.application.config.eager_load_paths.include?(reports_path) ?
         "  app/reports IS in eager load paths" :
         "  app/reports is NOT in eager load paths"

    puts "\nChecking namespace constants:\n"

    begin
      Base
      puts "   Base constant exists"
    rescue NameError
      puts "   Base constant missing"
    end

    base_dir = Rails.root.join("app/reports/base")
    puts "\nTesting base class loadability:"
    Dir[base_dir.join("*.rb")].each do |file|
      print "   Loading #{File.basename(file)} ... "
      begin
        require file
        puts "OK"
      rescue => e
        puts "FAILED (#{e.class}: #{e.message})"
      end
    end

    puts "\nTesting base class constants:"
    {
      ReportService:  "Base::ReportService",
      PdfRenderer:    "Base::PdfRenderer",
      SqlProvider:    "Base::SqlProvider",
      TemplateLoader: "Base::TemplateLoader",
      YamlLoader:     "Base::YamlLoader"
    }.each do |_short, full|
      print "   #{full} ... "
      begin
        full.constantize
        puts "OK"
      rescue => e
        puts "FAILED (#{e.class})"
      end
    end

    puts "\n=== REPORTS DOCTOR COMPLETE ===\n\n"
  end
end

# -------------------------------------------------------------------------- }}}
