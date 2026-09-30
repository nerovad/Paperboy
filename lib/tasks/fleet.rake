# frozen_string_literal: true

require 'csv'

namespace :fleet do
  # Loads the legacy Fleet garaging vehicle list (db/data/fleet_garaging_vehicles.psv)
  # into the fleet master, fleet_vehicles, so the vehicles appear in
  # Records > Fleet Vehicles and garaging forms can be filed against them.
  #
  # Rows are inserted with insert_all, bypassing the Records history: these are
  # the starting list, not edits anyone made.
  #
  # Idempotent and additive: vehicles are keyed on vehicle_number, and one
  # already on the list is left alone. Once loaded, the master is changed in
  # the app (Records grid, approved garaging forms), and a rerun must not
  # revert that to the legacy file.
  desc 'Load the legacy Fleet garaging vehicle list into the fleet master (idempotent)'
  task import_garaging: :environment do
    abort 'Refusing to run in production without ALLOW_PRODUCTION=1' if Rails.env.production? && ENV['ALLOW_PRODUCTION'] != '1'

    path = Rails.root.join('db/data/fleet_garaging_vehicles.psv')
    rows = CSV.read(path, col_sep: '|', headers: true, quote_char: "\x00").map(&:to_h)
    blank = ->(value) { value.to_s.strip.presence&.then { |v| ['[None]', 'NULL', 'Select One'].include?(v) ? nil : v } }

    # The vehicle's contact: the legacy contact, matched to an employee
    # by the local part of the address, since the list mixes @ventura.org,
    # @venturacounty.org and @venturacounty.gov. An unmatched contact keeps a
    # name derived from the address.
    contact_name = Hash.new do |cache, email|
      local = email.split(%r{[@/]}).first.to_s.strip.downcase
      employee = Employee.where('LOWER(email) LIKE ?', "#{Employee.sanitize_sql_like(local)}@%").first
      cache[email] = employee ? [employee.first_name, employee.last_name].compact.join(' ') : local.split('.').map(&:capitalize).join(' ')
    end

    # Agency of a budget unit (a Coa::Unit id), through its org chain.
    agency_of = Hash.new do |cache, budget_unit|
      unit = Coa::Unit.find_by(unit_id: budget_unit)
      department = unit && Coa::Department.find_by(department_id: unit.department_id)
      division = department && Coa::Division.find_by(division_id: department.division_id)
      cache[budget_unit] = division&.agency_id
    end

    on_file = FleetVehicle.where(vehicle_number: rows.map { |row| row['vehicle_number'].strip }).pluck(:vehicle_number).to_set
    fresh = rows.reject { |row| on_file.include?(row['vehicle_number'].strip) }

    if fresh.any?
      FleetVehicle.insert_all!(fresh.map do |v|
        updated = Date.strptime(v['date_updated'], '%m/%d/%Y').in_time_zone.change(hour: 12)
        budget_unit = v['budget_unit'].strip
        {
          vehicle_number: v['vehicle_number'].strip,
          budget_unit: budget_unit,
          agency: agency_of[budget_unit],
          contact_name: contact_name[v['email'].strip],
          make: v['make'].strip,
          model: v['model'].strip,
          year: v['year'].to_i,
          take_home: v['take_home'].strip.capitalize,
          garaging_location: blank.call(v['primary_garaging']),
          secondary_garaging_location: blank.call(v['secondary_garaging']),
          created_at: updated,
          updated_at: updated
        }
      end)
    end

    puts "  ✓ #{fresh.size} vehicles added, #{on_file.size} already on the fleet list"
  end
end
