# frozen_string_literal: true

# Fiscal's coding lookups (item b). Preview first, then apply; undo by import id.
#   bin/rails "aim:lookups:preview[/mnt/a/AIM/_Lookups/GSA/Fleet Lookup.csv,GSA]"
#   bin/rails "aim:lookups:apply[/path/file.csv,GSA,bdo]"      effective: bdo | today | date,YYYY-MM-DD
#   AIM_LOOKUP_UNIT=4641 for a file whose rows name no budget unit.
#   AIM_LOOKUP_ACCEPT=all or AIM_LOOKUP_ACCEPT=18,19 loads rows the COA objects to, with the objection as a warning.
#   bin/rails "aim:lookups:undo[12]"
namespace :aim do
  namespace :lookups do
    desc 'Read a lookup file and report what would load and what is refused'
    task :preview, %i[path agency] => :environment do |_, args|
      report = Aim::LookupImport.new(args[:path], agency: args[:agency], budget_unit: ENV.fetch('AIM_LOOKUP_UNIT', nil),
                                                  accept: accept_option).report
      puts "#{report[:file]} (#{report[:agency]}): #{report[:rows]} rows, #{report[:loadable]} loadable, #{report[:refused]} refused"
      puts "Columns not understood: #{report[:unknown_columns].join(', ')}" if report[:unknown_columns].any?
      report[:refused_rows].each do |r|
        puts "  row #{r[:row]} #{r[:vendor]}: #{r[:reasons].join('; ')}#{' (can be accepted)' if r[:acceptable]}"
      end
      report[:accepted_rows].each { |r| puts "  row #{r[:row]} accepted with a warning: #{r[:warnings].join('; ')}" }
      report[:noted_rows].each { |r| puts "  row #{r[:row]} loaded with a note: #{r[:notes].join('; ')}" }
    end

    desc 'Load a lookup file as coding rules'
    task :apply, %i[path agency effective date] => :environment do |_, args|
      by = ENV.fetch('AIM_IMPORTED_BY') { "#{ENV.fetch('USER', 'rake')}@rake" }
      import = Aim::LookupImport.new(args[:path], agency: args[:agency], effective: args[:effective] || 'bdo',
                                                  effective_date: args[:date] && Date.parse(args[:date]),
                                                  budget_unit: ENV.fetch('AIM_LOOKUP_UNIT', nil), accept: accept_option).apply!(by: by)
      puts "Import #{import.id}: #{import.loaded_count} loaded, #{import.refused_count} refused, " \
           "#{import.retired_count} earlier rules retired. Undo with aim:lookups:undo[#{import.id}]."
    end

    def accept_option
      value = ENV.fetch('AIM_LOOKUP_ACCEPT', '').strip
      return :none if value.empty?
      return :all if value.casecmp?('all')

      value.split(',').map { |n| n.strip.to_i }
    end

    desc 'Undo an import: its rules retired, the rules it retired restored'
    task :undo, %i[import_id] => :environment do |_, args|
      by = ENV.fetch('AIM_IMPORTED_BY') { "#{ENV.fetch('USER', 'rake')}@rake" }
      Aim::CodingImport.find(args[:import_id]).undo!(by: by)
      puts "Import #{args[:import_id]} undone."
    end
  end
end
