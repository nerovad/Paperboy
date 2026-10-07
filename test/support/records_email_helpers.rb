# frozen_string_literal: true

# Records emails go to county employees only, looked up in GSABSS. Tests name
# who counts as one instead of seeding Employees rows.
module RecordsEmailHelpers
  def with_county_employees(*emails, &block)
    county = lambda do |given|
      RecordsEmailRecipients.normalize(given).select { |email| emails.include?(email) }
    end

    RecordsEmailRecipients.stub(:county, county, &block)
  end

  def pacific(*args) = Time.find_zone('Pacific Time (US & Canada)').local(*args)

  def vehicle(number, agency, updated_at)
    FleetVehicle.create!(vehicle_number: number, agency: agency, updated_at: updated_at)
  end

  def email_rule(**attrs)
    RecordsEmailRule.new({ table_slug: 'fleet', column_name: 'updated_at', operator: 'on_or_before',
                           value: '2025-12-15', label: 'Out of compliance',
                           message: 'The following vehicles are out of compliance and need their locations updated',
                           split_column: 'agency', employee_id: '1001', frequency: 'weekly', day_of_week: 1,
                           time_of_day: '07:00' }.merge(attrs))
  end
end
