# app/models/employee.rb
class Employee < GsabssBase
  self.table_name = 'Employees'
  self.primary_key = 'EmployeeID'

  # Column aliases: MSSQL PascalCase → Rails snake_case
  alias_attribute :employee_id, :EmployeeID
  alias_attribute :first_name, :First_Name
  alias_attribute :last_name, :Last_Name
  alias_attribute :email, :EE_Email
  alias_attribute :work_phone, :Work_Phone
  alias_attribute :supervisor_id, :Supervisor_ID
  alias_attribute :supervisor_first_name, :Supervisor_First_Name
  alias_attribute :supervisor_last_name, :Supervisor_Last_Name
  alias_attribute :job_title, :Job_Title
  alias_attribute :job_code, :Job_Code
  alias_attribute :job_class, :Job_Class
  alias_attribute :pay_status, :Pay_Status
  alias_attribute :union_code, :Union_Code
  alias_attribute :employee_type, :Type
  alias_attribute :agency, :Agency
  alias_attribute :department, :Department
  alias_attribute :unit, :Unit
  alias_attribute :position, :Position

  has_many :employee_groups, foreign_key: 'EmployeeID', primary_key: 'EmployeeID'
  has_many :groups, through: :employee_groups

  # Helper method to check group membership
  def in_group?(name)
    groups.exists?(Group_Name: name)
  end

  # Helper to check multiple groups (user needs ANY of them)
  def in_any_group?(*group_names)
    groups.where(Group_Name: group_names).exists?
  end

  # Returns all employee IDs in the reporting chain beneath the given manager
  # (direct reports, their reports, etc.) Does NOT include the manager themselves.
  def self.subordinate_ids(manager_id)
    collected = []
    queue = [manager_id.to_s]

    while queue.any?
      direct_report_ids = where(Supervisor_ID: queue).pluck(:EmployeeID).map(&:to_s)
      direct_report_ids -= collected # avoid cycles
      direct_report_ids -= [manager_id.to_s]
      break if direct_report_ids.empty?

      collected.concat(direct_report_ids)
      queue = direct_report_ids
    end

    collected
  end
end
