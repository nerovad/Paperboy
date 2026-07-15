# frozen_string_literal: true

# lib/tasks/app.rake
require_relative '../paperboy/app_builder'

namespace :app do
  desc 'Scaffold a new sidebar app. Usage: rake app:new[hello_world] or rake app:new[hello_world,"Hello World"] ' \
       '(env: LABEL=, THEME=teal|blue|cyan|slate|green, DRY_RUN=1)'
  task :new, %i[name label] => :environment do |_t, args|
    name = args[:name] || ENV.fetch('NAME', nil)
    if name.blank?
      puts 'Usage: rake app:new[hello_world]'
      puts '       rake app:new[hello_world,"Hello World"]'
      puts '       THEME=blue DRY_RUN=1 rake app:new[hello_world]'
      exit 1
    end

    dry_run = ENV.fetch('DRY_RUN', nil).present?

    begin
      app = Paperboy::AppBuilder.new(name, label: args[:label] || ENV.fetch('LABEL', nil), theme: ENV.fetch('THEME', nil))
      files = app.call(dry_run: dry_run)
    rescue Paperboy::AppBuilder::Error, Paperboy::AppRegistrar::MissingAnchorError => e
      abort "[FAIL] #{e.message}"
    end

    puts dry_run ? "Dry run — #{app.label} (#{app.key}), nothing written:" : "Created #{app.label} (#{app.key}):"
    created = app.new_files.keys
    files.each_key { |path| puts "  #{created.include?(path) ? '[NEW] ' : '[EDIT]'} #{path}" }

    if dry_run
      puts "\nRe-run without DRY_RUN=1 to write these files."
      next
    end

    puts <<~NEXT

      Next steps:
        1. Restart the server so the new namespace and controllers load.
        2. Grant access: ACL > pick a group > Permissions > Applications > #{app.label}.
           Until you do, nobody but a system admin can see or open it —
           application access is a strict allow-list with no default grants.
        3. Rebuild assets to pick up the sidebar theme. In dev:
             bin/rails assets:clobber assets:precompile && sudo systemctl restart paperboy-dev.service
        4. Build the app: add controllers under app/controllers/#{app.key}/ that
           inherit from #{app.module_name}::BaseController, and views under
           app/views/#{app.key}/. Add sidebar buttons in
           app/views/#{app.key}/shared/_sidebar.html.erb.
    NEXT
  end

  desc 'List the apps registered in the sidebar app switcher'
  task list: :environment do
    rows = [%w[paperboy Paperboy] + ['always available']]
    rows += AclController::APPLICATION_ITEMS.map { |item| [item[:key], item[:label], 'granted under ACL > Applications'] }
    puts '  KEY              LABEL                    ACL'
    rows.each { |row| puts format('  %-16s %-24s %s', *row) }
  end
end
