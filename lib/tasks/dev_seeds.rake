# lib/tasks/dev_seeds.rake
namespace :dev do
  desc "Seed Parking Lot only (SUBMISSIONS=n, REPLANT=1 optional)"
  task "seed:parking" => :environment do
    require Rails.root.join("db/seeds/parking_lot")
    Seeds::ParkingLot.run(replant: ENV["REPLANT"] == "1")
  end

  desc "Seed Probation only (TRANSFERS=n, REPLANT=1 optional)"
  task "seed:probation" => :environment do
    require Rails.root.join("db/seeds/probation")
    Seeds::Probation.run(replant: ENV["REPLANT"] == "1")
  end

  desc "Seed all (REPLANT=1 optional)"
  task "seed:all" => :environment do
    require Rails.root.join("db/seeds/parking_lot")
    require Rails.root.join("db/seeds/probation")
    Seeds::ParkingLot.run(replant: ENV["REPLANT"] == "1")
    Seeds::Probation.run(replant: ENV["REPLANT"] == "1")
  end
end
