namespace :bike_lockers do
  # Seeds the bike-locker reference data — the 13 lots and the physical locker
  # inventory — from the legacy repgen LotNames / LockerRanges tables. Every
  # locker is seeded as `available`; current occupancy is NOT imported (the
  # request workflow assigns lockers going forward). Idempotent and safe across
  # deploys: lots match on name, lockers on (lot, number).
  #
  # Lot names are normalized out of the legacy ALL-CAPS (VANGUARD -> Vanguard).
  # The leading number is the legacy LotID, kept only to group the inventory.
  LOTS = [
    [ 1,  "E Lot" ],
    [ 2,  "G Lot" ],
    [ 3,  "H Lot" ],
    [ 4,  "R Lot" ],
    [ 5,  "A Lot" ],
    [ 6,  "ECCH" ],
    [ 7,  "669 CSD" ],
    [ 8,  "TRB" ],
    [ 9,  "Vanguard" ],
    [ 10, "Williams" ],
    [ 11, "Partridge" ],
    [ 12, "Saticoy Yard" ],
    [ 13, "FJC Ventura" ]
  ].freeze

  # legacy LotID => locker numbers in that lot. Numbers repeat across lots
  # (E Lot, R Lot, ECCH, Saticoy all have a "1") — they are unique only per lot.
  LOCKERS = {
    1  => [ 1, 2, 3, 4, 15, 16, 17, 18 ],
    2  => [ 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 19, 20, 21, 22, 23, 24, 25, 26,
           27, 28, 29, 30, 31, 32, 33, 34, 35, 36, 37, 38, 39, 40, 41, 42 ],
    3  => [ 53, 54, 55, 56, 57, 58, 59, 60, 61, 62, 63, 64, 65, 66, 67, 68 ],
    4  => [ 1, 2, 3, 4, 5, 6, 7, 8 ],
    5  => [ 43, 44, 45, 46, 47, 48, 49, 50, 51, 52 ],
    6  => [ 1, 2, 3, 4 ],
    7  => [ 69, 70, 71, 72, 73, 74, 75, 76, 77, 78, 79, 80, 81, 82, 83, 84 ],
    8  => [ 85, 86, 87, 88, 89, 90, 91, 92, 93, 94, 95, 96 ],
    9  => [ 1087, 1088, 1089, 1090, 1091, 1092, 1093, 1094 ],
    10 => [ 1095, 1096, 1097, 1098 ],
    11 => [ 53, 54, 55, 56, 57, 58, 59, 60 ],
    12 => [ 1, 2, 3, 4, 15, 16, 17, 18 ],
    13 => [ 64, 65 ]
  }.freeze

  desc "Seed bike_locker_lots + bike_lockers from the legacy repgen tables (idempotent)"
  task seed: :environment do
    by_legacy_id = {}

    LOTS.each do |legacy_id, name|
      lot = BikeLockerLot.find_or_create_by!(name: name)
      by_legacy_id[legacy_id] = lot
    end
    puts "  ✓ #{BikeLockerLot.count} lots"

    created = 0
    LOCKERS.each do |legacy_lot_id, numbers|
      lot = by_legacy_id.fetch(legacy_lot_id)
      numbers.each do |number|
        locker = BikeLocker.find_or_initialize_by(lot_id: lot.id, locker_number: number)
        created += 1 if locker.new_record?
        locker.save! if locker.new_record?
      end
    end
    puts "  ✓ #{BikeLocker.count} lockers (#{created} new this run)"
    puts "Done."
  end
end
