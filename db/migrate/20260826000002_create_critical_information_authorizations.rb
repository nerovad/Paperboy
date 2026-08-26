# frozen_string_literal: true

class CreateCriticalInformationAuthorizations < ActiveRecord::Migration[8.0]
  # The Critical Information Reporting authorization console. A CIR is routed
  # to an incident manager by the "Where: Location" field, so a row is just
  # (location -> employee_id) — no service types, budget units or org nodes.
  #
  # `location` holds a CriticalInformationLocation name verbatim, which is what
  # the form's location dropdown submits. That catalogue was still a frozen
  # array in the code when this ran; CreateCriticalInformationLocations moves it
  # into its own table straight after. One manager per
  # location: CriticalInformationReporting#assigned_manager_id is a single
  # column, so a second manager could never be reached.
  #
  # The seed below is the mapping that used to live in
  # CriticalInformationLocationRouter::LOCATION_MANAGER_MAP, already resolved
  # against the location catalogue by that class's fuzzy matcher. It is baked in
  # as a literal rather than recomputed so the migration keeps producing the
  # same table after the matcher is gone. 171 of the 212 catalogue locations
  # matched; the other 41 have never routed anywhere and are left unassigned for
  # the console to fill in. Eleven locations matched two managers under the old
  # fuzzy rules; each is seeded with the one the router actually returned (first
  # match wins), so routing behaviour is unchanged on the day this runs.
  SEED = {
    'AGOURA-899 N. KANAN RD.' => '121520',
    'CAMARILLO-106 DURLEY AVE.' => '126471',
    'CAMARILLO-1203 FLYNN RD. UNIT 220' => '126471',
    'CAMARILLO-1401 AVIATION DR.' => '126471',
    'CAMARILLO-1401 AVIATION DR. V 20' => '126471',
    'CAMARILLO-160 DURLEY AVE.' => '126471',
    'CAMARILLO-165 DURLEY AVE.' => '126471',
    'CAMARILLO-1722 LEWIS RD.' => '126471',
    'CAMARILLO-1732 LEWIS RD.' => '126471',
    'CAMARILLO-1750 LEWIS RD.' => '137554',
    'CAMARILLO-1756 S. LEWIS' => '137554',
    'CAMARILLO-1758 LEWIS RD. CASA E' => '137554',
    'CAMARILLO-1760 LEWIS RD. CASA D' => '137554',
    'CAMARILLO-189 S. LAS POSAS RD.' => '126471',
    'CAMARILLO-2160 PICKWICK DR.' => '126471',
    'CAMARILLO-295 WILLIS AVE' => '126471',
    'CAMARILLO-333 SKYWAY DR.' => '137554',
    'CAMARILLO-345 SKYWAY DR.' => '126471',
    'CAMARILLO-350 WILLIS AVE.' => '126471',
    'CAMARILLO-355 POST ST.' => '126471',
    'CAMARILLO-3701 LAS POSAS RD.' => '126471',
    'CAMARILLO-375 DURLEY AVE.' => '126471',
    'CAMARILLO-3760 CALLE TECATE' => '126471',
    'CAMARILLO-3801 LAS POSAS STE 214' => '137554',
    'CAMARILLO-403 VALLEY VISTA DR.' => '126471',
    'CAMARILLO-5171 VERDUGO WAY' => '126471',
    'CAMARILLO-5353 SANTA ROSA RD.' => '126471',
    'CAMARILLO-555 AIRPORT WAY' => '126471',
    'CAMARILLO-600 AVIATION DR.' => '126471',
    'CAMRILLO-102 DURLEY AVE.' => '126471',
    'FILLMORE-3824 GUIBERSON RD.' => '126471',
    'FILLMORE-502 2ND STREET' => '126471',
    'FILLMORE-524 SESPE AVE.' => '126471',
    'FILLMORE-613 OLD TELEGRAPH RD' => '126471',
    'FILLMORE-828 W. VENTURA ST.' => '137554',
    'FRAZIER PARK-15011 LOCKWOOD VALLEY RD.' => '128975',
    'FRAZIER PARK-15031 LOCKWOOD VALLEY RD' => '128975',
    'FRAZIER PARK-15051 LOCKWOOD VALLEY RD.' => '128975',
    'MALIBU-11855 PACIFIC COAST HWY (PCH)' => '126471',
    'MALIBU-928 LATIGO CANYON RD.' => '126471',
    'MOORPARK-11501 CHAMPIONSHIP DR.' => '121520',
    'MOORPARK-15698 1/2 CAMPUS PARK DR.' => '121520',
    'MOORPARK-295 E. HIGH STREET' => '126471',
    'MOORPARK-4185 CEDAR SPRINGS' => '126471',
    'MOORPARK-610 SPRING RD.' => '121520',
    'MOORPARK-612 SPRING RD.' => '121520',
    'MOORPARK-612 SPRING RD BLDG A' => '121520',
    'MOORPARK-6767 SPRING RD. BLDG A' => '121520',
    'MOORPARK-6767 SPRING RD. BLDG B' => '121520',
    'MOORPARK-6767 SPRING RD. BLDG C' => '121520',
    'MOORPARK-7150 WALNUT CANYON RD.' => '121520',
    'MOORPARK-9550 LOS ANGELES AVE' => '121520',
    'NEWBURY PARK-2400 CONEJO SPECTRUM ST.' => '126471',
    'NEWBURY PARK-2500 W HILL CREST DR.' => '126471',
    'NEWBURY PARK-751 MITCHELL RD.' => '126471',
    'NEWBURY PARK-830 S. REINO RD' => '126471',
    'OAK PARK-855 DEERHILL RD' => '126471',
    'OAK VIEW-15 KUNKLE ST' => '126471',
    'OJAI-111 E OJAI AVE.' => '124502',
    'OJAI-12000 OJAI SANTA PAULA RD.' => '126471',
    'OJAI-1201 E OJAI RD' => '126471',
    'OJAI-1768 MARICOPA HIGHWAY' => '124502',
    'OJAI-400 S LOMITA AVE.' => '124502',
    'OJAI-402 S. VENTURA ST.' => '124502',
    'OJAI-466 S LA LUNA' => '126471',
    'OXNARD-1051 YARNELL PLACE' => '137554',
    'OXNARD-133 C ST.' => '126471',
    'OXNARD-1400 VANGUARD RD.' => '137554',
    'OXNARD-1721 PACIFIC AVE.' => '137554',
    'OXNARD-2000 OUTLET CENTER DR.' => '137554',
    'OXNARD-2130 VENTURA RD.' => '137554',
    'OXNARD-2220 E. GONZALES RD.' => '137554',
    'OXNARD-2240 E.GONZALES' => '137554',
    'OXNARD-2400 SOUTH C ST.' => '137554',
    'OXNARD-2420 CELSIUS AVE, UNIT A & B' => '137554',
    'OXNARD-2431 LATIGO AVE.' => '126471',
    'OXNARD-2451 LATIGO AVE.' => '126471',
    'OXNARD-2471 LATIGO AVE.' => '126471',
    'OXNARD-2500 SOUTH C ST. STE A & B' => '137554',
    'OXNARD-2500 SOUTH C ST., STE C & D' => '137554',
    'OXNARD-2643 SAVIERS RD.' => '137554',
    'OXNARD-2697 SAVIERS RD (2697 "C" ST).' => '137554',
    'OXNARD-2791 PARK VIEW COURT' => '137554',
    'OXNARD-2820 JOURDAN ST.' => '137554',
    'OXNARD-2901 VENTURA RD. 2ND/3RD FLOOR' => '137554',
    'OXNARD-3100 N. ROSE AVE' => '137554',
    'OXNARD-325 W. CHANNEL ISLANDS BLVD.' => '137554',
    'OXNARD-3302 TURNOUT CIRCLE' => '126471',
    'OXNARD-4333 VINEYARD AVE.' => '124502',
    'OXNARD-4353 VINEYARD' => '120131',
    'OXNARD-545/555 SOUTH A ST.' => '137554',
    'OXNARD-545 CENTRAL AVE.' => '137554',
    'PIRU-2815 TELEGRAPH RD.' => '126471',
    'PIRU-3811 CENTER ST.' => '126471',
    'PIRU-3977 CENTER ST' => '126471',
    'PIRU-513 N CHURCH ST' => '126471',
    'PORT HUENEME-304 2ND ST.' => '126471',
    'PORT HUENEME-510 PARK AVE .' => '137554',
    'SANTA PAULA-114 S. 10TH ST.' => '126471',
    'SANTA PAULA-12391 W. TELEGRAPH RD' => '126471',
    'SANTA PAULA-12727 OJAI RD' => '126471',
    'SANTA PAULA-1334 E. MAIN ST.' => '126471',
    'SANTA PAULA-254 W. HARVARD BLVD.' => '126471',
    'SANTA PAULA-536 W MAIN ST.' => '126471',
    'SANTA PAULA-600 S TODD RD.' => '121520',
    'SANTA PAULA-620 W. HARVARD BLVD' => '126471',
    'SANTA PAULA-630 TODD RD' => '126471',
    'SANTA PAULA-725 E. MAIN ST.' => '126471',
    'SANTA PAULA-815 SANTA BARBARA ST.' => '126471',
    'SANTA PAULA-821 SANTA BARBARA ST.' => '126471',
    'SATICOY-11201-A RIVERBANK DR.' => '126471',
    'SATICOY-11251-B RIVERBANK DR.' => '126471',
    'SIMI VALLEY-1050 COUNTRY CLUB DR.' => '126471',
    'SIMI VALLEY-1910 CHURCH ST' => '126471',
    'SIMI VALLEY-2003 ROYAL AVE.' => '121520',
    'SIMI VALLEY-2639 AVENIDA AVE' => '121520',
    'SIMI VALLEY-2900 MADERA RD.' => '121520',
    'SIMI VALLEY-2901 ERRINGER RD,' => '126471',
    'SIMI VALLEY-3150 E LOS ANGELES AVE.' => '121520',
    'SIMI VALLEY-3265 N TAPO CYN' => '126471',
    'SIMI VALLEY-3855 ALAMO ST.' => '121520',
    'SIMI VALLEY-5874 E. LOS ANGELES AVE.' => '126471',
    'SIMI VALLEY-7535 SANTA SUSANA RD.' => '121520',
    'SIMI VALLEY-790 PACIFIC AVE' => '126471',
    'SIMI VALLEY-980 ENCHANTED WAY' => '121520',
    'SOMIS-3356 SOMIS RD' => '126471',
    'THOUSAND OAKS-125 W. THOUSAND OAKS BLVD' => '137554',
    'THOUSAND OAKS-151 DUESENBERG DR' => '126471',
    'THOUSAND OAKS-2010 UPPER RANCH RD.' => '126471',
    'THOUSAND OAKS-2100 E. T.O. BLVD' => '121520',
    'THOUSAND OAKS-2101 E. OLSEN RD' => '121520',
    'THOUSAND OAKS-2977 MOUNTCLEFF BLVD' => '126471',
    'THOUSAND OAKS-325 W HILLCREST DR' => '126471',
    'THOUSAND OAKS-33 LAKE SHERWOOD DR.' => '126471',
    'THOUSAND OAKS-555 AVENIDA DE LOS ARBOLES' => '126471',
    'THOUSAND OAKS-80 E. HILLCREST DR.' => '121520',
    'VENTURA-1000 S. HILL RD.' => '120131',
    'VENTURA-1001 PARTRIDGE DR.' => '120131',
    'VENTURA-1070 HILL RD. STE 1' => '120131',
    'VENTURA-1190 S VICTORIA AVE UNIT 200' => '124502',
    'VENTURA-1957 EASTMAN AVE.' => '126471',
    'VENTURA-2189 EASTMAN AVE.' => '137554',
    'VENTURA-2323 KNOLL DR.' => '124502',
    'VENTURA-2575 VISTA DEL MAR' => '124502',
    'VENTURA-2982 MARTHA DR' => '124502',
    'VENTURA-3160 LOMA VISTA RD' => '124502',
    'VENTURA-3170 LOMA VISTA RD' => '124502',
    'VENTURA-3180 LOMA VISTA RD' => '124502',
    'VENTURA-4245 MARKET STREET' => '126471',
    'VENTURA-4567 TELEPHONE RD' => '126471',
    'VENTURA-4601 TELEPHONE RD.' => '126471',
    'VENTURA-4651 TELEPHONE RD' => '126471',
    'VENTURA-5600 EVERGLADES ST. UNIT A & B' => '124502',
    'VENTURA-5720 RALSTON STE 300' => '124502',
    'VENTURA-5777 N. VENTURA AVE.' => '124502',
    'VENTURA-5851 THILLE ST.' => '124502',
    'VENTURA-606 N. VENTURA AVE' => '124502',
    'VENTURA-6401 TELEPHONE RD.' => '120131',
    'VENTURA-646 COUNTY SQUARE DR.' => '124502',
    'VENTURA-651 MAIN ST.' => '124502',
    'VENTURA-669 COUNTY SQ DR' => '124502',
    'VENTURA-77 CALIFORNIA ST.' => '124502',
    'VENTURA-789 VICTORIA AVE' => '124502',
    'VENTURA-800 S VICTORIA AVE' => '120131',
    'VENTURA-800 S VICTORIA AVE (HOA)' => '120131',
    'VENTURA-800 S. VICTORIA AVE (HOJ)' => '120131',
    'VENTURA-800 S. VICTORIA AVE (PTDF)' => '120131',
    'VENTURA-800 S. VICTORIA AVE (PTDF Annex)' => '120131',
    'VENTURA-800 S. VICTORIA AVE (Service Building)' => '120131',
    'VENTURA-855 PARTRIDGE DR.' => '120131',
    'VENTURA-RINCON-5674 W. PACIFIC COAST HWY-PCH' => '126471'
  }.freeze

  class MigrationAuthorization < ActiveRecord::Base
    self.table_name = 'critical_information_authorizations'
  end

  def up
    return if table_exists?(:critical_information_authorizations)

    create_table :critical_information_authorizations do |t|
      t.string :location, null: false
      t.string :employee_id, null: false
      t.string :authorized_by

      t.timestamps
    end

    add_index :critical_information_authorizations, :employee_id
    add_index :critical_information_authorizations, :location, unique: true

    now = Time.current
    MigrationAuthorization.insert_all(
      SEED.map { |location, employee_id| { location: location, employee_id: employee_id, created_at: now, updated_at: now } }
    )
  end

  def down
    drop_table :critical_information_authorizations if table_exists?(:critical_information_authorizations)
  end
end
