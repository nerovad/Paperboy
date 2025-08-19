module ApplicationHelper
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

  # app/helpers/application_helper.rb
  def format_phone(digits)
    d = digits.to_s.gsub(/\D/, "")
    return digits if d.length != 10
    "#{d[0,3]}-#{d[3,3]}-#{d[6,4]}"
  end
end
