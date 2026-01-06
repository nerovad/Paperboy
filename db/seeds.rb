# db/seeds.rb
if !Rails.env.development? && !Rails.env.test?
  puts "Refusing to seed in #{Rails.env}"
  exit
end

require_relative "seeds/shared"
require_relative "seeds/parking_lot"
require_relative "seeds/probation"
require_relative "seeds/critical_information_reporting"

only = ENV["ONLY"] # "parking" or "probation"
replant = ENV["REPLANT"] == "1"

case only
when "parking"
  Seeds::ParkingLot.run(replant: replant)
when "cir"
  Seeds::CriticalInformationReporting.run(replant: replant)
when "probation"
  Seeds::Probation.run(replant: replant)
else
  Seeds::ParkingLot.run(replant: replant)
  Seeds::Probation.run(replant: replant)
  Seeds::CriticalInformationReporting.run(replant: replant)
end

puts "✅ Seeding complete."
