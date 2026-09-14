# frozen_string_literal: true

require 'csv'

namespace :fleet do
  # Loads the legacy Fleet garaging vehicle list (db/data/fleet_garaging_vehicles.psv)
  # as approved Fleet Vehicle Garaging submissions, so the vehicles appear in
  # Records > Fleet Vehicles. One submission per (contact email, budget unit).
  #
  # Rows are inserted with insert_all, bypassing TrackableStatus callbacks: these
  # are historical records, and a normal create would mail approvers and
  # subscribers about ~120 "new" submissions.
  #
  # Idempotent: vehicles are keyed on vehicle_number. A rerun deletes the
  # previously imported vehicles and the submissions that hold only those, then
  # loads the file again.
  desc 'Import the legacy Fleet garaging vehicle list as approved submissions (idempotent)'
  task import_garaging: :environment do
    abort 'Refusing to run in production without ALLOW_PRODUCTION=1' if Rails.env.production? && ENV['ALLOW_PRODUCTION'] != '1'

    path = Rails.root.join('db/data/fleet_garaging_vehicles.psv')
    rows = CSV.read(path, col_sep: '|', headers: true, quote_char: "\x00").map(&:to_h)
    blank = ->(value) { value.to_s.strip.presence&.then { |v| ['[None]', 'NULL', 'Select One'].include?(v) ? nil : v } }

    # Submission header for one contact + budget unit. The org chain comes from
    # the budget unit (a Coa::Unit id). The contact is matched to an employee by
    # the local part of the address, since the legacy list mixes @ventura.org,
    # @venturacounty.org and @venturacounty.gov; unmatched contacts keep a name
    # derived from the address and no employee_id.
    submission_attributes = lambda do |email, budget_unit|
      unit = Coa::Unit.find_by(unit_id: budget_unit)
      department = unit && Coa::Department.find_by(department_id: unit.department_id)
      division = department && Coa::Division.find_by(division_id: department.division_id)

      local = email.split(%r{[@/]}).first.to_s.strip.downcase
      employee = Employee.where('LOWER(email) LIKE ?', "#{Employee.sanitize_sql_like(local)}@%").first

      {
        name: employee ? [employee.first_name, employee.last_name].compact.join(' ') : local.split('.').map(&:capitalize).join(' '),
        email: email,
        phone: employee&.work_phone,
        employee_id: employee&.id&.to_s,
        agency: division&.agency_id,
        division: division&.division_id,
        department: department&.department_id,
        unit: unit&.unit_id
      }
    end

    ActiveRecord::Base.transaction do
      numbers = rows.pluck('vehicle_number')
      existing = FleetVehicle.where(vehicle_number: numbers)
      form_ids = existing.distinct.pluck(:fleet_vehicle_garaging_form_id)
      existing.delete_all
      FleetVehicleGaragingForm.where(id: form_ids).where.not(id: FleetVehicle.select(:fleet_vehicle_garaging_form_id)).delete_all
      puts "  - removed #{form_ids.size} previously imported submissions" if form_ids.any?

      rows.group_by { |row| [row['email'].strip, row['budget_unit'].strip] }.each do |(email, budget_unit), vehicles|
        stamp = vehicles.map { |v| Date.strptime(v['date_updated'], '%m/%d/%Y') }.max.in_time_zone.change(hour: 12)
        attrs = submission_attributes.call(email, budget_unit).merge(status: 'approved', created_at: stamp, updated_at: stamp)
        form_id = FleetVehicleGaragingForm.insert!(attrs, returning: [:id]).rows.first.first

        FleetVehicle.insert_all!(vehicles.map do |v|
          updated = Date.strptime(v['date_updated'], '%m/%d/%Y').in_time_zone.change(hour: 12)
          {
            fleet_vehicle_garaging_form_id: form_id,
            vehicle_number: v['vehicle_number'].strip,
            budget_unit: budget_unit,
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
    end

    imported = FleetVehicle.where(vehicle_number: rows.pluck('vehicle_number'))
    puts "  ✓ #{imported.distinct.count(:fleet_vehicle_garaging_form_id)} submissions, #{imported.count} vehicles"
  end
end
