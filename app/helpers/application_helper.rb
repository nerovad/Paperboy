# app/helpers/application_helper.rb
module ApplicationHelper
  def current_user
    session[:user]
  end
  
  # Number of items currently in the signed-in user's inbox, for the profile
  # and tab badges. Uses the same InboxQuery the inbox page runs (scoped to the
  # user's own queue), so the badge always matches the page and never "clears"
  # on viewing. Memoized per request — the badge renders more than once.
  def inbox_count
    return @inbox_count if defined?(@inbox_count)

    employee_id = session[:user]&.dig("employee_id")
    @inbox_count =
      if employee_id.blank?
        0
      else
        InboxQuery.new(scoped_employee_ids: [employee_id.to_s]).count
      end
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
