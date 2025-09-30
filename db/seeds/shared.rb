# db/seeds/shared.rb
module Seeds
  SEED_KEY = (ENV["SEED_KEY"] || "2025-09-30").hash
  srand SEED_KEY

  STATUSES = { pending: 0, approved: 1, denied: 2 }.freeze

  SUPERVISORS = [
    { id: "132497", name: "David Barley",      email: "David.Barley@ventura.org" },
    { id: "103597", name: "Christopher Payne", email: "Christopher.Payne@ventura.org" },
    { id: "104236", name: "Sean Payne",        email: "Sean.Payne@ventura.org" }
  ].freeze

  AGENCIES   = %w[GSA Probation IT HR].freeze
  DIVISIONS  = ["Operations", "Admin", "Special Services", "Adult Programs"].freeze
  DEPARTMENTS= ["Operations Support", "Field Services", "Court Services"].freeze
  UNITS      = %w[MB3 ISSJ PSU VFS OFS-1 OFS-2 AI-1 AI-2 AI-3].freeze

  # Parking lots & vehicles
  LOTS    = ["R Lot", "A", "B", "C", "Visitor", "Overflow"].freeze
  COLORS  = %w[Black White Silver Gray Blue Red Green].freeze
  MAKES_MODELS = [
    ["Toyota", %w[Camry Corolla RAV4 Prius]],
    ["Honda",  %w[Civic Accord CR-V Fit]],
    ["Ford",   %w[F-150 Escape Focus Explorer]],
    ["Tesla",  %w[Model\ 3 Model\ Y Model\ S]],
    ["Subaru", %w[Outback Forester Crosstrek Impreza]],
    ["Chevy",  %w[Silverado Malibu Equinox Bolt]]
  ].freeze

  # Probation
  WORK_LOCATIONS = [
    "Adult Court Services","Adult Field Services","AI-1","AI-2","AI-3","ISSJ",
    "JF Detention","JF Programming","PSU","STU","VFS","OFS-1","OFS-2"
  ].freeze

  FIRST = %w[Matthew Gary Sarah Priya Jose Andre Emily Chris Jordan Taylor Alex Casey Morgan Jamie Robin].freeze
  LAST  = %w[Davoren Howard Kim Patel Garcia Johnson Lee Martinez Brown Davis Wilson Clark Hughes Rivera Chen].freeze

  module_function

  def name() "#{FIRST.sample} #{LAST.sample}" end
  def email_for(n) n.downcase.gsub(" ", ".") + "@ventura.org" end
  def phone()
    if rand < 0.2
      "805/#{600 + rand(400)}-#{1000 + rand(9000)}"
    else
      "%03d%03d%04d" % [310, 600 + rand(400), 1000 + rand(9000)]
    end
  end
  def employee_id() (100000 + rand(900000)).to_s end
  def plate() [("A".."Z").to_a.sample(3).join, rand(100..999), ("A".."Z").to_a.sample].join end
end
