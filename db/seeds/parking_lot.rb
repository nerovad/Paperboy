# db/seeds/parking_lot.rb
require_relative "shared"

module Seeds
  module ParkingLot
    module_function

    def run(count: ENV.fetch("SUBMISSIONS", "120").to_i, replant: ENV["REPLANT"] == "1")
      if replant
        ParkingLotVehicle.delete_all
        ParkingLotSubmission.delete_all
      end

      puts "→ Seeding #{count} parking lot submissions…"
      ActiveRecord::Base.transaction do
        count.times do
          sup = SUPERVISORS.sample

          # weighted status
          status = case rand
                   when 0...0.60 then STATUSES[:pending]
                   when 0.60...0.85 then STATUSES[:approved]
                   else STATUSES[:denied]
                   end

          person = Seeds.name
          created_at = rand(120).days.ago + rand(0..23).hours + rand(0..59).minutes
          updated_at = created_at + rand(0..20).days

          approved_by = approved_at = denied_by = denied_at = denial_reason = nil
          if status == STATUSES[:approved]
            approved_by = sup[:id]
            approved_at = created_at + rand(1..7).days
            updated_at  = [updated_at, approved_at].max
          elsif status == STATUSES[:denied]
            denied_by     = sup[:id]
            denied_at     = created_at + rand(1..7).days
            denial_reason = ["Incomplete information","Not eligible","Duplicate request","Invalid plate"].sample
            updated_at    = [updated_at, denied_at].max
          end

          sub = ParkingLotSubmission.create!(
            name: person,
            phone: Seeds.phone,
            employee_id: Seeds.employee_id,
            email: Seeds.email_for(person),
            agency: AGENCIES.sample,
            division: DIVISIONS.sample,
            department: DEPARTMENTS.sample,
            unit: UNITS.sample,
            status: status,
            supervisor_id: sup[:id],
            supervisor_email: sup[:email],
            approved_by: approved_by,
            approved_at: approved_at,
            denied_by: denied_by,
            denied_at: denied_at,
            denial_reason: denial_reason,
            created_at: created_at,
            updated_at: updated_at
          )

          rand(1..3).times do
            make, models = MAKES_MODELS.sample
            lot = LOTS.sample
            other = (lot == "Visitor" && rand < 0.3) ? ["Overflow East","Overflow West","Underground","Roof"].sample : nil

            ParkingLotVehicle.create!(
              parking_lot_submission_id: sub.id,
              make: make,
              model: models.sample,
              color: COLORS.sample,
              year: rand(2000..2025),
              license_plate: Seeds.plate,
              parking_lot: lot,
              other_parking_lot: other,
              created_at: sub.created_at + rand(0..3).days,
              updated_at: updated_at
            )
          end
        end
      end
    end
  end
end
