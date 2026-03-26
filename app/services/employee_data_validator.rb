class EmployeeDataValidator
  VALID_EMAIL_DOMAINS = %w[ventura.org].freeze

  Issue = Struct.new(:category, :field, :message, :severity, keyword_init: true)

  Result = Struct.new(:employee, :issues, keyword_init: true) do
    def valid?
      issues.none? { |i| i.severity == :error }
    end

    def error_count
      issues.count { |i| i.severity == :error }
    end

    def warning_count
      issues.count { |i| i.severity == :warning }
    end
  end

  def initialize
    @valid_unit_keys = Set.new
    @unit_lookup = {}
    @valid_agency_ids = Set.new
    @valid_employee_ids = Set.new
    @employees_with_groups = Set.new
  end

  def validate_all
    preload_lookup_data
    employees = Employee.all.to_a
    employees.map { |emp| validate(emp) }
  end

  def validate(employee)
    issues = []
    check_email(employee, issues)
    check_name(employee, issues)
    check_work_phone(employee, issues)
    check_supervisor(employee, issues)
    check_agency(employee, issues)
    check_org_chain(employee, issues)
    check_group_membership(employee, issues)
    Result.new(employee: employee, issues: issues)
  end

  def summary(results)
    total = results.size
    valid = results.count(&:valid?)
    with_errors = total - valid
    with_warnings = results.count { |r| r.valid? && r.warning_count > 0 }

    by_category = Hash.new(0)
    results.each do |r|
      r.issues.each { |i| by_category[i.category] += 1 }
    end

    {
      total: total,
      valid: valid,
      with_errors: with_errors,
      with_warnings: with_warnings,
      by_category: by_category
    }
  end

  private

  def preload_lookup_data
    # Build unit composite key set: "agency_id|unit_id"
    Unit.pluck(:agency_id, :division_id, :department_id, :unit_id).each do |aid, did, dept_id, uid|
      key = uid.strip
      @valid_unit_keys << key
      @unit_lookup[key] = { agency_id: aid&.strip, division_id: did&.strip, department_id: dept_id&.strip }
    end

    @valid_agency_ids = Set.new(Agency.pluck(:agency_id).map(&:strip))
    @valid_employee_ids = Set.new(Employee.pluck(:EmployeeID))
    @employees_with_groups = Set.new(EmployeeGroup.distinct.pluck(:EmployeeID))
  end

  def check_email(emp, issues)
    email = emp.email&.strip
    if email.blank?
      issues << Issue.new(category: :email, field: "EE_Email", message: "Email is blank", severity: :error)
      return
    end

    domain = email.split("@").last&.downcase
    unless VALID_EMAIL_DOMAINS.include?(domain)
      issues << Issue.new(
        category: :email, field: "EE_Email",
        message: "Non-county email domain: @#{domain}",
        severity: :error
      )
    end
  end

  def check_name(emp, issues)
    if emp.first_name.blank?
      issues << Issue.new(category: :name, field: "First_Name", message: "First name is blank", severity: :error)
    end
    if emp.last_name.blank?
      issues << Issue.new(category: :name, field: "Last_Name", message: "Last name is blank", severity: :error)
    end
  end

  def check_work_phone(emp, issues)
    if emp.work_phone.blank?
      issues << Issue.new(category: :phone, field: "Work_Phone", message: "Work phone is blank", severity: :warning)
    end
  end

  def check_supervisor(emp, issues)
    sup_id = emp.supervisor_id
    if sup_id.blank?
      issues << Issue.new(
        category: :supervisor, field: "Supervisor_ID",
        message: "No supervisor assigned",
        severity: :error
      )
    elsif !@valid_employee_ids.include?(sup_id)
      issues << Issue.new(
        category: :supervisor, field: "Supervisor_ID",
        message: "Supervisor ID #{sup_id} does not exist in Employees table",
        severity: :error
      )
    end
  end

  def check_agency(emp, issues)
    agency = emp.agency&.strip
    if agency.blank?
      issues << Issue.new(category: :agency, field: "Agency", message: "Agency is blank", severity: :error)
      return
    end

    unless @valid_agency_ids.include?(agency)
      issues << Issue.new(
        category: :agency, field: "Agency",
        message: "Agency \"#{agency}\" not found in agencies table",
        severity: :error
      )
    end
  end

  def check_org_chain(emp, issues)
    unit_code = emp.unit&.strip
    if unit_code.blank?
      issues << Issue.new(category: :org_chain, field: "Unit", message: "Unit is blank", severity: :error)
      return
    end

    unless @valid_unit_keys.include?(unit_code)
      issues << Issue.new(
        category: :org_chain, field: "Unit",
        message: "Unit \"#{unit_code}\" not found in units table — org chain broken",
        severity: :error
      )
      return
    end

    # Unit exists — verify it belongs to the employee's agency
    chain = @unit_lookup[unit_code]
    emp_agency = emp.agency&.strip
    if chain && emp_agency.present? && chain[:agency_id] != emp_agency
      issues << Issue.new(
        category: :org_chain, field: "Unit",
        message: "Unit \"#{unit_code}\" belongs to agency \"#{chain[:agency_id]}\" but employee is in agency \"#{emp_agency}\"",
        severity: :error
      )
    end
  end

  def check_group_membership(emp, issues)
    unless @employees_with_groups.include?(emp.EmployeeID)
      issues << Issue.new(
        category: :groups, field: "Groups",
        message: "Not a member of any group",
        severity: :warning
      )
    end
  end
end
