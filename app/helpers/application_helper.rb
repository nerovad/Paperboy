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
    current_user_group_names.include?("system_admins")
  end


  def fetch_acl_groups
    Group.order(:group_name).pluck(:group_name, :id)
  rescue
    []
  end
end
