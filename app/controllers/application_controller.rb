class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern
  before_action :set_current_user
  helper_method :current_user, :inbox_count, :current_user_group_names, :current_user_group_ids

  def current_user
    user_data = session[:user]
    return nil unless user_data&.dig("employee_id") && user_data&.dig("email")

    @current_user ||= SessionUser.new(
      employee_id: user_data["employee_id"],
      email: user_data["email"],
      first_name: user_data["first_name"],
      last_name: user_data["last_name"]
    )
  end

    def inbox_count
    return @inbox_count if defined?(@inbox_count)

    user = session[:user]
    return @inbox_count = 0 unless user && user["employee_id"].present?

    eid = user["employee_id"].to_s

    # Parking Lot: pending for this supervisor
    pl = ParkingLotSubmission.where(supervisor_id: eid, status: 0)
    # If you later add cancelation to parking lot, this line will automatically exclude them:
    pl = pl.where(canceled_at: nil) if ParkingLotSubmission.column_names.include?("canceled_at")

    # Probation Transfer: pending & NOT canceled
    ptr = ProbationTransferRequest.where(supervisor_id: eid, status: 0, canceled_at: nil)

    @inbox_count = pl.count + ptr.count
  end

  def build_prefill_data(employee_id)
    employee = Employee.find_by(EmployeeID: employee_id)
    return {} unless employee

    unit_code = employee["Unit"]
    unit = Unit.find_by(unit_id: unit_code)
    department = Department.find_by(department_id: unit&.department_id)
    division   = Division.find_by(division_id: department&.division_id)
    agency     = Agency.find_by(agency_id: division&.agency_id)

    {
      employee_id: employee["EmployeeID"],
      name: "#{employee["First_Name"]} #{employee["Last_Name"]}",
      phone: employee["Work_Phone"],
      email: employee["EE_Email"],
      agency: agency&.agency_id,
      division: division&.division_id,
      department: department&.department_id,
      unit: unit ? "#{unit.unit_id} - #{unit.long_name}" : nil
    }
  end

  # Memoized group names (Set) and group IDs (Array) for the current user.
  # Loaded once per request via a single JOIN query.
  def current_user_group_names
    load_current_user_groups unless defined?(@_current_user_group_names)
    @_current_user_group_names
  end

  def current_user_group_ids
    load_current_user_groups unless defined?(@_current_user_group_ids)
    @_current_user_group_ids
  end

  def require_system_admin
    unless current_user_group_names.include?("system_admins")
      redirect_to root_path, alert: "Access denied. System administrators only."
    end
  end

  private

  def load_current_user_groups
    employee_id = session.dig(:user, "employee_id")

    if employee_id.present?
      rows = ActiveRecord::Base.connection.execute(<<~SQL)
        SELECT g.Group_Name, eg.GroupID
        FROM GSABSS.dbo.Employee_Groups eg
        JOIN GSABSS.dbo.Groups g ON eg.GroupID = g.GroupID
        WHERE eg.EmployeeID = #{ActiveRecord::Base.connection.quote(employee_id)}
      SQL

      names = Set.new
      ids   = []
      rows.each do |row|
        names << row["Group_Name"].downcase
        ids   << row["GroupID"]
      end

      @_current_user_group_names = names
      @_current_user_group_ids   = ids
    else
      @_current_user_group_names = Set.new
      @_current_user_group_ids   = []
    end
  rescue
    @_current_user_group_names = Set.new
    @_current_user_group_ids   = []
  end

  def set_current_user
    Current.user = session[:user]
  end
end
