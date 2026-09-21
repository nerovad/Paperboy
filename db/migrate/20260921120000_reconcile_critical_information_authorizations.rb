# frozen_string_literal: true

class ReconcileCriticalInformationAuthorizations < ActiveRecord::Migration[8.1]
  # Brings the CIR authorization console in line with Facilities' maintenance
  # coverage sheets (revised 10/2025 - 07/2026), which they supplied as the
  # current word on who covers each site. The sheet wins wherever it and the
  # console disagree.
  #
  # Written as a migration rather than clicked into each console so dev, stage
  # and prod end up identical. Every step is keyed on the location name and is
  # idempotent: a site this database does not have is skipped, and a site
  # already assigned is overwritten with the sheet's manager.
  ERIC_URIAS      = '137554'
  JOEY_CARMONA    = '124502'
  ANNETTE_CARDONA = '126471'
  ROBERT_LANGLEY  = '105354'
  STEVEN_BLAIR    = '120131'

  ASSIGNMENTS = {
    # Unassigned sites the sheets cover. The HCA clinic sheet names no
    # manager; Eric Urias covers every other HCA clinic in the console.
    'OXNARD-1701 SOLAR DR.' => ERIC_URIAS,
    'OXNARD-1801 SOLAR DR.' => ERIC_URIAS,
    'OXNARD-1911 WILLIAMS DR.' => ERIC_URIAS,
    'OXNARD-341 BERNOULLI CIR.' => ERIC_URIAS,
    'SIMI VALLEY-1133-B LOS ANGELES AVE.' => ERIC_URIAS,
    'SIMI VALLEY-1227 E. LOS ANGELES AVE.' => ERIC_URIAS,
    'SIMI VALLEY-1900 Los Angeles Ave' => ERIC_URIAS,
    'SIMI VALLEY-670 W LA AVE.' => ERIC_URIAS,
    'VENTURA-133 W. SANTA CLARA ST' => ERIC_URIAS,
    'VENTURA-3100 FOOTHILL RD.' => ERIC_URIAS,
    'VENTURA-4258 TELEGRAPH' => ERIC_URIAS,
    'VENTURA-5740 RALSTON- HCA' => ERIC_URIAS,
    'VENTURA-5850 THILLE RD' => ERIC_URIAS,
    'VENTURA-67 E BARNETT ST' => ERIC_URIAS,
    'OJAI-555 MAHONEY AVE' => JOEY_CARMONA,
    'VENTURA-11220 AZAHAR ST.' => ANNETTE_CARDONA,
    'VENTURA-1292 LOS ANGELES AVE' => ANNETTE_CARDONA,
    # On the DSET sheet only.
    'OXNARD-3334 SANTA CLARA AVE' => ROBERT_LANGLEY,
    'SIMI VALLEY-2969 TAPO CANYON RD.' => ROBERT_LANGLEY,

    # Assigned, but not to the manager the sheet names.
    'MOORPARK-612 SPRING RD BLDG A' => ERIC_URIAS,
    'SANTA PAULA-254 W. HARVARD BLVD.' => ERIC_URIAS,
    'SANTA PAULA-620 W. HARVARD BLVD' => ERIC_URIAS,
    'SANTA PAULA-1334 E. MAIN ST.' => ERIC_URIAS,
    'SANTA PAULA-12727 OJAI RD' => JOEY_CARMONA,
    'SATICOY-11201-A RIVERBANK DR.' => JOEY_CARMONA,
    'SATICOY-11251-B RIVERBANK DR.' => JOEY_CARMONA,
    'SIMI VALLEY-3855 ALAMO ST.' => STEVEN_BLAIR
  }.freeze

  # Second spellings of a site that is already on the form. Deleting one takes
  # its authorization with it, as the console does; reports filed under it keep
  # the string they were submitted with.
  DUPLICATE_LOCATIONS = [
    'CAMARILLO-1401 AVIATION DR. V 20',   # CAMARILLO-1401 AVIATION DR.
    'CAMARILLO-3100 PONDEROSA DR .'       # CAMARILLO-3100 PONDEROSA DR.
  ].freeze

  class MigrationLocation < ActiveRecord::Base
    self.table_name = 'critical_information_locations'
  end

  class MigrationAuthorization < ActiveRecord::Base
    self.table_name = 'critical_information_authorizations'
  end

  def up
    MigrationAuthorization.where(location: DUPLICATE_LOCATIONS).delete_all
    MigrationLocation.where(name: DUPLICATE_LOCATIONS).delete_all

    present = MigrationLocation.where(name: ASSIGNMENTS.keys).pluck(:name).to_set
    ASSIGNMENTS.each do |location, employee_id|
      next unless present.include?(location)

      row = MigrationAuthorization.find_or_initialize_by(location: location)
      row.employee_id = employee_id
      row.save!
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
