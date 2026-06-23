# app/helpers/application_helper.rb
module ApplicationHelper
  def current_user
    session[:user]
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
    Group.order(:Group_Name).pluck(:Group_Name, :GroupID)
  rescue
    []
  end
end
