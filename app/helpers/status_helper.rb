# app/helpers/status_helper.rb
module StatusHelper
  def status_badge_class(status_string)
    case status_string.to_s
    when "submitted"         then "is-submitted"
    when "manager_approved"  then "is-manager-approved"
    when "denied"            then "is-denied"
    when "sent_to_security", "sent_to_hr", "sent_to_next"
      "is-sent"
    else
      "is-submitted"  # fallback
    end
  end
end
