# db/seeds/critical_information_reporting.rb
require "securerandom"
require_relative "shared"

module Seeds
  module CriticalInformationReporting
    module_function

    def run(count: ENV.fetch("CIR", "80").to_i, replant: ENV["REPLANT"] == "1")
      if replant
        ::CriticalInformationReporting.delete_all
      end

      puts "→ Seeding #{count} critical information reports…"

      incident_types = [
        "Network Outage", "Application Issue", "Facilities Problem", "Security Incident",
        "Vendor Issue", "Power/Utility", "Staffing Disruption", "Other"
      ].freeze

      urgencies = ["Low", "Medium", "High", "Critical"].freeze
      impacts = ["Low", "Medium", "High"].freeze
      locations = ["HOA", "Government Center", "Field Office - East", "Field Office - West", "Remote"].freeze

      ActiveRecord::Base.transaction do
        count.times do
          sup = SUPERVISORS.sample
          person = Seeds.name

          created_at = rand(120).days.ago + rand(0..23).hours + rand(0..59).minutes
          updated_at = created_at + rand(0..14).days

          impact_started = created_at - rand(0..6).hours
          incident_type = incident_types.sample
          urgency = urgencies.sample
          impact = impacts.sample
          location = locations.sample

          status = case rand
                   when 0...0.50 then :in_progress
                   when 0.50...0.65 then :scheduled
                   when 0.65...0.85 then :resolved
                   else :cancelled
                   end

          actual_completion_date =
            if status == :resolved && rand < 0.8
              impact_started + rand(2..72).hours
            elsif status == :cancelled && rand < 0.3
              impact_started + rand(2..24).hours
            end

          incident_details = <<~TEXT.strip
            Seeded CIR for testing + Power BI.
            Type: #{incident_type}
            Location: #{location}
            Ref: #{SecureRandom.hex(4)}
          TEXT

          cause = [
            "Configuration change", "Hardware failure", "Vendor outage",
            "Human error", "Unknown / under investigation", "Capacity constraints"
          ].sample

          staff_involved = [
            "IT Ops", "Facilities", "Security", "Vendor Support", "Field Staff", "None"
          ].sample

          impacted_customers =
            case impact
            when "Minor"    then rand(1..10).to_s
            when "Moderate" then rand(10..50).to_s
            when "Major"    then rand(50..200).to_s
            else                 rand(200..1000).to_s
            end

          next_steps =
            if status == :cancelled
              "No action taken. #{["Need more details and resubmit.", "Duplicate report.", "Route to correct team."].sample}"
            else
              ["Monitor and confirm stability.", "Notify stakeholders.", "Create follow-up ticket.", "Schedule RCA review."].sample
            end

          ::CriticalInformationReporting.create!(
            employee_id: Seeds.employee_id,
            name: person,
            phone: phone = "%03d-%03d-%04d" % [805, rand(200..999), rand(1000..9999)],
            email: Seeds.email_for(person),
            agency: AGENCIES.sample,
            division: DIVISIONS.sample,
            department: DEPARTMENTS.sample,
            unit: UNITS.sample,
            incident_type: incident_type,
            incident_details: incident_details,
            cause: cause,
            staff_involved: staff_involved,
            impact_started: impact_started,
            location: location,
            status: status,
            actual_completion_date: actual_completion_date,
            urgency: urgency,
            impact: impact,
            impacted_customers: impacted_customers,
            next_steps: next_steps,
            created_at: created_at,
            updated_at: updated_at
          )
        end
      end
    end
  end
end
