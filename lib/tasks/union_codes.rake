namespace :union_codes do
  # Seeds the employee_union_codes table with known union/bargaining-unit
  # memberships. Idempotent — safe to re-run, and safe across deploys. Edit
  # SEED_CODES as membership changes (this is a manual stopgap until a real
  # source feed or admin UI exists). Employee IDs are looked up once and pasted
  # here so the task does not depend on name matching at run time.
  SEED_CODES = [
    { employee_id: "104236", name: "Sean Payne",   union_code: "MB3" },
    { employee_id: "132497", name: "David Barley", union_code: "MB3" }
  ].freeze

  desc "Seed employee_union_codes with known union memberships (idempotent)"
  task seed: :environment do
    SEED_CODES.each do |row|
      rec = EmployeeUnionCode.find_or_initialize_by(employee_id: row[:employee_id])
      rec.union_code = row[:union_code]
      rec.save!
      puts "  ✓ #{row[:name]} (#{row[:employee_id]}) → #{row[:union_code]}"
    end
    puts "Done. #{EmployeeUnionCode.count} union code rows total."
  end
end
