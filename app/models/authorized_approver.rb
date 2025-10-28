# app/models/authorized_approver.rb
class AuthorizedApprover < ApplicationRecord
  validates :employee_id, presence: true
  validates :department_id, presence: true
  validates :service_type, presence: true, inclusion: { in: %w[P E V C K] }
  validates :key_type, inclusion: { in: %w[1 2 3 4 5 6 7] }, if: -> { service_type == 'K' }
  validates :span, inclusion: { in: %w[A B C D E] }, allow_blank: true
  
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
  
  def employee
    Employee.find_by(EmployeeID: employee_id)
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
end
