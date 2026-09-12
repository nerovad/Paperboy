# frozen_string_literal: true

require 'fileutils'

namespace :reports do
  desc 'Scaffold a report. Usage: rake reports:new[family,report_name]'
  task :new, %i[family name] => :environment do |_task, args|
    family = report_slug(args[:family])
    name = report_slug(args[:name])
    report_root = Rails.root.join('app/reports', family, name)
    template_file = Rails.root.join('config/reports/template/template.pdf')
    report_pdf = report_root.join("#{name}.pdf")
    report_config = report_root.join("#{name}.yml")

    FileUtils.mkdir_p(report_root)

    if report_pdf.exist?
      puts "Template exists: #{report_pdf}"
    else
      FileUtils.cp(template_file, report_pdf) if template_file.file?
      puts "Copied starter template: #{report_pdf}" if report_pdf.exist?
    end

    if report_config.exist?
      puts "Configuration exists: #{report_config}"
    else
      report_config.write(<<~YAML)
        # Coordinates are PDF points measured from the bottom-left corner.
        # The starter template was copied from #{template_file}.
        #
        family: #{family}
        name: #{name}
        template:
          filename: #{name}.pdf
        overlay:
          enabled: true
          fields: {}
      YAML
      puts "Created configuration: #{report_config}"
    end

    puts "WARNING: shared template not found: #{template_file}" unless template_file.file?

    puts "\nReport scaffold '#{family}/#{name}' created successfully."
  end

  desc 'Destroy a report scaffold. Usage: rake reports:destroy[family,report_name]'
  task :destroy, %i[family name] => :environment do |_task, args|
    family = report_slug(args[:family])
    name = report_slug(args[:name])
    report_root = Rails.root.join('app/reports', family, name)

    abort "Refusing to destroy #{family}/#{name}; set FORCE=1 to continue." unless ENV['FORCE']

    FileUtils.rm_rf(report_root)
    puts "Destroyed report scaffold '#{family}/#{name}'."
  end

  def report_slug(value)
    slug = value.to_s.underscore
    return slug if slug.match?(/\A[a-z][a-z0-9_]*\z/)

    abort 'Usage: rake reports:new[family,report_name]'
  end
end
