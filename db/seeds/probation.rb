# db/seeds/probation.rb
require_relative "shared"

module Seeds
  module Probation
    module_function

    def run(count: ENV.fetch("TRANSFERS", "60").to_i, replant: ENV["REPLANT"] == "1")
      ProbationTransferRequest.delete_all if replant

      puts "→ Seeding #{count} probation transfer requests…"
      ActiveRecord::Base.transaction do
        count.times do
          sup = SUPERVISORS.sample
          status = case rand
                   when 0...0.55 then STATUSES[:pending]
                   when 0.55...0.85 then STATUSES[:approved]
                   else STATUSES[:denied]
                   end

          person = Seeds.name
          created_at = rand(180).days.ago
          updated_at = [created_at + rand(1..45).days, Time.current].min

          approved_by = approved_at = denied_by = denied_at = denial_reason = nil
          approved_destination = nil

          if status == STATUSES[:approved]
            approved_by = sup[:id]
            approved_at = created_at + rand(3..20).days
            approved_destination = WORK_LOCATIONS.sample
            updated_at = [updated_at, approved_at].max
          elsif status == STATUSES[:denied]
            denied_by = sup[:id]
            denied_at = created_at + rand(3..20).days
            denial_reason = ["Position unavailable","Not enough tenure","Missing training","Staffing needs"].sample
            updated_at = [updated_at, denied_at].max
          end

          # Occasionally expired or canceled
          expires_at = (rand < 0.15 ? rand(15..90).days.from_now : nil)
          canceled   = (rand < 0.10)
          canceled_at = canceled ? (created_at + rand(1..30).days) : nil
          canceled_reason = canceled ? ["Employee withdrew request","Moved to another unit","Created in error"].sample : nil

          ProbationTransferRequest.create!(
            employee_id: Seeds.employee_id,
            name: person,
            email: Seeds.email_for(person),
            phone: Seeds.phone,
            agency: "Probation",
            division: DIVISIONS.sample,
            department: DEPARTMENTS.sample,
            unit: UNITS.sample,
            work_location: WORK_LOCATIONS.sample,
            current_assignment_date: rand(300).days.ago,
            desired_transfer_destination: WORK_LOCATIONS.sample,
            other_transfer_destination: (rand < 0.2 ? "Special Unit Rotation" : nil),
            status: status,
            approved_by: approved_by,
            approved_at: approved_at,
            denied_by: denied_by,
            denied_at: denied_at,
            denial_reason: denial_reason,
            supervisor_email: sup[:email],
            supervisor_id: sup[:id],
            expires_at: expires_at,
            canceled_at: canceled_at,
            canceled_reason: canceled_reason,
            superseded_by_id: nil,
            approved_destination: approved_destination,
            created_at: created_at,
            updated_at: updated_at
          )
        end
      end
    end
  end
end
