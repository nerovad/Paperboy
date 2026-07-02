# app/helpers/application_helper.rb
module ApplicationHelper
  def current_user
    session[:user]
  end

  def format_phone(digits)
    d = digits.to_s.gsub(/\D/, "")
    return digits if d.length != 10
    "#{d[0, 3]}-#{d[3, 3]}-#{d[6, 4]}"
  end

  def format_pst(time, format: :short)
    return nil unless time
    l(time.in_time_zone("Pacific Time (US & Canada)"), format: format)
  end

  def environment_badge(host: request.host, rails_env: Rails.env)
    env_name = rails_env.to_s

    if localhost_host?(host)
      { label: "LOCALHOST", css_class: "is-localhost" }
    elsif env_name == "development"
      { label: "Development", css_class: "is-development" }
    elsif env_name == "staging"
      { label: "Stage", css_class: "is-staging" }
    end
  end

  def system_admin?
    current_user_group_names.include?("system_admins")
  end


  def fetch_acl_groups
    Group.order(:Group_Name).pluck(:Group_Name, :GroupID)
  rescue
    []
  end

  private

  def localhost_host?(host)
    [ "localhost", "127.0.0.1", "::1" ].include?(host.to_s)
  end
end
