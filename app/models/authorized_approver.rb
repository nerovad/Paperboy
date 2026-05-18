# app/models/authorized_approver.rb
class AuthorizedApprover < ApplicationRecord
  validates :employee_id, presence: true
  validates :department_id, presence: true
  validates :service_type, presence: true, inclusion: { in: %w[P E V C K] }
  validates :key_type, inclusion: { in: %w[1 2 3 4 5 6 7] }, if: -> { service_type == 'K' }
  validates :span, inclusion: { in: %w[A B C D E] }, allow_blank: true
  validates :employee_id, uniqueness: {
    scope: [:department_id, :service_type, :key_type],
    message: "is already authorized for this service type in this department"
  }
  
  SERVICE_TYPES = {
    'P' => 'Parking Permits',
    'E' => 'Employee Identification Badges',
    'V' => 'Volunteer ID Badges',
    'C' => 'Vendor ID Badges',
    'K' => 'Facility Keys and Security Access'
  }.freeze
  
  KEY_TYPES = {
    '1' => 'Master Keys',
    '2' => 'Access Cards',
    '3' => 'Site Keys',
    '4' => 'Area / Room Keys',
    '5' => 'Perimeter Fence Gates',
    '6' => 'Equipment Closet Keys',
    '7' => 'File/Desk/Storage Cabinet Keys'
  }.freeze
  
  SPANS = {
    'A' => 'All Budget Units - All Locations',
    'B' => 'Multiple Budget Units - All Locations',
    'C' => 'Multiple Budget Units - Multiple Locations',
    'D' => 'Single Budget Unit - Multiple Locations',
    'E' => 'Single Budget Unit - Single Location'
  }.freeze

  LOCATIONS = [
    "1190 S. Victoria Ave., Suite 200, Ventura, CA 93003",
    "2220 E Gonzales Rd.",
    "2220 Gonzales, 2240 Gonzales, 1801 Solar Dr, 1701 Solar Dr",
    "2240 E Gonzales Rd.",
    "5171 Verdugo Way, Camarillo, CA 93012 / HOJ, Room 302, Ventura, CA 93009",
    "555 Airport Way, Suite B, Camarillo",
    "A/B/C/D/E",
    "All Ambulatory Care",
    "All ANM Bldgs",
    "All ANM Buildings",
    "All GSA Maint. Bldgs during Project",
    "All GSA Maintained Buildings",
    "All GSA-Maint. Bldgs during Projects",
    "All GSA-Maintained Bldgs",
    "All GSA-maintained buildings",
    "All HSA Facilities",
    "All ITSD Locations",
    "All JF Locations",
    "All Locations",
    "All Units/VCPA Locations",
    "APCD",
    "C",
    "Camarillo/Santa Paula/Saticoy",
    "District office, Gov't Center",
    "Fillmore Clinic Activity",
    "FIRE FCC",
    "Harbor",
    "HOA",
    "HOA & JJC",
    "HOA EHS",
    "HOA HCA General Access",
    "HOA Lower Plaza",
    "HOA/Main/Assessor",
    "HOJ, ECC, JC, Hill & Ralston",
    "HOJ, UBB, JJC",
    "Law Library",
    "Magnolia Clinic activity",
    "MEO & E. Cnty Sheriff gate (gas)",
    "Parks, Facilities",
    "Same Budget #'s and Locations for all employees listed",
    "Saticoy",
    "Svc Bldg",
    "Svc Bldg, HOA"
  ].freeze
  
  def employee
    Employee.find_by(employee_id: employee_id)
  end
  
  def department
    Department.find_by(department_id: department_id)
  end
  
  def service_type_label
    SERVICE_TYPES[service_type] || service_type
  end
  
  def key_type_label
    KEY_TYPES[key_type] || key_type
  end
  
  def span_label
    SPANS[span] || span
  end
  
  # Find approvers for a given department and service type
  def self.approvers_for(department_id:, service_type:)
    where(department_id: department_id, service_type: service_type).pluck(:employee_id).uniq
  end

  # Find approvers for a given department, service type, and budget unit.
  # Span 'A' (All Budget Units) matches any unit. All other spans require
  # the unit to appear in the approver's comma-separated budget_units list.
  def self.approver_for_unit(department_id:, service_type:, unit_id:)
    candidates = where(department_id: department_id, service_type: service_type)
    unit_str = unit_id.to_s

    candidates.select { |a|
      a.span == 'A' || a.budget_units.to_s.split(',').map(&:strip).include?(unit_str)
    }.map(&:employee_id).uniq
  end

  # Returns every unit_id this employee is authorized to approve for the given
  # service type. Span 'A' expands to all units in the approver's department;
  # other spans use the explicit budget_units list.
  def self.authorized_unit_ids_for(employee_id:, service_type:)
    rows = where(employee_id: employee_id, service_type: service_type)
    return [] if rows.empty?

    unit_ids = Set.new
    rows.each do |a|
      if a.span == 'A'
        Unit.where(department_id: a.department_id).pluck(:unit_id).each { |u| unit_ids << u.to_s }
      else
        a.budget_units.to_s.split(',').map(&:strip).each { |u| unit_ids << u if u.present? }
      end
    end
    unit_ids.to_a
  end
end
