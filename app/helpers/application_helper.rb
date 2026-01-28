# app/helpers/application_helper.rb
module ApplicationHelper
  def current_user
    session[:user]
  end
  
  def inbox_count
    return 0 unless session[:user]&.dig("employee_id")
    
    submissions = ParkingLotSubmission.where(
      supervisor_id: session[:user]["employee_id"],
      status: 0
    )
    
    if session[:last_seen_inbox_at].present?
      submissions = submissions.where("created_at > ?", session[:last_seen_inbox_at])
    end
    
    submissions.count
  end
  
  def format_phone(digits)
    d = digits.to_s.gsub(/\D/, "")
    return digits if d.length != 10
    "#{d[0,3]}-#{d[3,3]}-#{d[6,4]}"
  end

  def format_pst(time, format: :short)
    return nil unless time
    l(time.in_time_zone("Pacific Time (US & Canada)"), format: format)
  end
  
  def system_admin?
    return false unless session[:user_id]
    
    employee_id = session.dig(:user, "employee_id")
    return false unless employee_id
    
    result = ActiveRecord::Base.connection.execute(
      "SELECT COUNT(*) as count 
       FROM GSABSS.dbo.Employee_Groups eg
       JOIN GSABSS.dbo.Groups g ON eg.GroupID = g.GroupID
       WHERE eg.EmployeeID = #{employee_id} 
       AND g.Group_Name = 'system_admins'"
    ).first
    
    result && result['count'].to_i > 0
  rescue
    false
  end

  def fetch_acl_groups
    result = ActiveRecord::Base.connection.execute(
      "SELECT GroupID, Group_Name FROM GSABSS.dbo.Groups ORDER BY Group_Name"
    )
    
    result.map { |row| [row['Group_Name'], row['GroupID']] }
  rescue
    []
  end
end
