# app/services/critical_information_location_router.rb
class CriticalInformationLocationRouter
  # Mapping of normalized location patterns to incident manager employee IDs
  LOCATION_MANAGER_MAP = {
    # Vincent Childs - 121520
    "121520" => [
      "SANTA PAULA-600 TODD RD",
      "MOORPARK-612 SPRING RD BLDG B",
      "MOORPARK-15698 1/2 CAMPUS",
      "MOORPARK-6767 SPRING RD BLDG A",
      "MOORPARK-6767 SPRING RD BLDG B",
      "MOORPARK-6767 SPRING RD BLDG C",
      "MOORPARK-9550 LOS ANGELES AVE",
      "MOORPARK-7150 WALNUT",
      "MOORPARK-610 SPRING RD",
      "MOORPARK-11501 CHAMPIONSHIP",
      "OAK PARK-899 N KANAN",
      "AGOURA-899 N KANAN",
      "SIMI VALLEY-3150 E LOS ANGELES AVE",
      "SIMI VALLEY-2639 AVENIDA",
      "SIMI VALLEY-3855 ALAMO ST",
      "SIMI VALLEY-2900 MADERA",
      "SIMI VALLEY-2003 ROYAL",
      "SIMI VALLEY-5800 WOOLSEY",
      "SIMI VALLEY-7535 SANTA SUSANA",
      "SIMI VALLEY-980 ENCHANTED WAY",
      "T.OAKS-2101 E OLSEN",
      "THOUSAND OAKS-2101 E OLSEN",
      "T.OAKS-80 E HILLCREST",
      "THOUSAND OAKS-80 E HILLCREST",
      "T.OAKS-2100 THOUSAND OAKS BLVD",
      "THOUSAND OAKS-2100 THOUSAND OAKS BLVD",
      "THOUSAND OAKS-2100 E T.O. BLVD"
    ],

    # Colleen Cardona - 126471
    "126471" => [
      "CAMARILLO-160 DURLEY",
      "CAMARILLO-2400 CONEJO SPECTRUM",
      "NEWBURY PARK-2400 CONEJO SPECTRUM",
      "CAMARILLO-102 DURLEY",
      "CAMRILLO-102 DURLEY",
      "CAMARILLO-189 S LAS POSAS",
      "CAMARILLO-5353 SANTA ROSA",
      "CAMARILLO-2160 PICKWICK",
      "CAMARILLO-403 VALLEY VISTA",
      "FILLMORE-613 OLD TELEGRAPH",
      "FILLMORE-613 W TELEGRAPH",
      "OXNARD-133 C ST",
      "MALIBU-11855 PACIFIC COAST HWY",
      "MALIBU-11855 E PCH",
      "OJAI-466 S LA LUNA",
      "MOORPARK-4185 CEDAR SPRINGS",
      "MOORPARK-295 E HIGH",
      "NEWBURY PARK-830 S REINO",
      "NEWBURY PARK-2500 W HILL CREST",
      "NEWBURY PARK-751 MITCHELL",
      "OAK PARK-855 DEERHILL",
      "OAK VIEW-15 KUNKLE",
      "FILLMORE-3824 GUIBERSON",
      "FILLMORE-502 2ND",
      "FILLMORE-502 SECOND",
      "FILLMORE-524 SESPE",
      "PIRU-3977 CENTER",
      "PIRU-3811 CENTER",
      "PIRU-2815 TELEGRAPH",
      "PIRU-513 N CHURCH",
      "SANTA PAULA-815 SANTA BARBARA",
      "SANTA PAULA-725 E MAIN",
      "SANTA PAULA-12000 SANTA PAULA",
      "SANTA PAULA-12000 OJAI",
      "OJAI-12000 OJAI SANTA PAULA",
      "SATICOY-11220 AZAHAR",
      "SATICOY-1292 LOS ANGELES",
      "VENTURA-1957 EASTMAN",
      "VENTURA-4245 MARKET",
      "VENTURA-4567 TELEPHONE",
      "VENTURA-4601 TELEPHONE",
      "VENTURA-4651 TELEPHONE",
      "SIMI VALLEY-1910 CHURCH",
      "SIMI VALLEY-5874 E LOS ANGELES",
      "SIMI VALLEY-1050 COUNTRY CLUB",
      "SIMI VALLEY-790 PACIFIC",
      "SIMI VALLEY-3265 N TAPO",
      "SIMI VALLEY-2901 ERRINGER",
      "SOMIS-3356 SOMIS",
      "THOUSAND OAKS-325 W HILLCREST",
      "THOUSAND OAKS-151 DUESENBERG",
      "THOUSAND OAKS-151 N DUESENBERG",
      "THOUSAND OAKS-25 LAKE SHERWOOD",
      "THOUSAND OAKS-33 LAKE SHERWOOD",
      "THOUSAND OAKS-555 AVENIDA DE LOS ARBOLES",
      "THOUSAND OAKS-2977 MOUNTCLEF",
      "THOUSAND OAKS-2010 UPPER RANCH",
      "VENTURA-5674 W PCH",
      "VENTURA-5674 W PACIFIC COAST HWY",
      "CAMARILLO-165 DURLEY",
      "CAMARILLO-600 AVIATION",
      "CAMARILLO-5171 VERDUGO",
      "CAMARILLO-555 AIRPORT WAY",
      "CAMARILLO-1722 LEWIS",
      "CAMARILLO-1722 S LEWIS",
      "CAMARILLO-355 POST",
      "CAMARILLO-350 WILLIS",
      "CAMARILLO-345 SKYWAY",
      "CAMARILLO-1732 LEWIS",
      "CAMARILLO-1732 S LEWIS",
      "CAMARILLO-106 DURLEY",
      "CAMARILLO-3701 LAS POSAS",
      "CAMARILLO-3701 E LAS POSAS",
      "CAMARILLO-1401 AVIATION",
      "CAMARILLO-375 DURLEY",
      "CAMARILLO-3760 CALLE TECATE",
      "CAMARILLO-295 WILLIS",
      "CAMARILLO-1203 FLYNN",
      "CAMARILLO-460 CALLE SAN PABLO",
      "MALIBU-928 LATIGO",
      "OXNARD-2451 LATIGO",
      "OXNARD-2431 LATIGO",
      "OXNARD-2471 LATIGO",
      "OXNARD-3302 TURNOUT",
      "PORT HUENEME-304 2ND",
      "SANTA PAULA-114 S 10TH",
      "SANTA PAULA-12391 W TELEGRAPH",
      "SANTA PAULA-12727 OJAI",
      "SANTA PAULA-1334 E MAIN",
      "SANTA PAULA-254 W HARVARD",
      "SANTA PAULA-536 W MAIN",
      "SANTA PAULA-600 S TODD",
      "SANTA PAULA-620 W HARVARD",
      "SANTA PAULA-630 TODD",
      "SANTA PAULA-821 SANTA BARBARA",
      "SATICOY-11201 RIVERBANK",
      "SATICOY-11251 RIVERBANK",
      "OJAI-1201 OJAI",
      "OJAI-1201 E OJAI"
    ],

    # Joey Carmona - 124502
    "124502" => [
      "OXNARD-4333 VINEYARD",
      "OAK VIEW-555 MAHONEY",
      "OJAI-111 E OJAI",
      "OJAI-400 S LOMITA",
      "OJAI-1768 MARICOPA",
      "OJAI-402 S VENTURA",
      "OJAI-12727 SANTA PAULA",
      "SATICOY-11201 A RIVERBANK",
      "SATICOY-11201 B RIVERBANK",
      "SATICOY-11201 G RIVERBANK",
      "SATICOY-11251 RIVERBANK",
      "VENTURA-646 COUNTY SQUARE",
      "VENTURA-669 COUNTY SQUARE",
      "VENTURA-606 N VENTURA",
      "VENTURA-2323 KNOLL",
      "VENTURA-5720 RALSTON",
      "VENTURA-3160 LOMA VISTA",
      "VENTURA-3170 LOMA VISTA",
      "VENTURA-3180 LOMA VISTA",
      "VENTURA-2982 MARTHA",
      "VENTURA-789 VICTORIA",
      "VENTURA-789 S VICTORIA",
      "VENTURA-651 E MAIN",
      "VENTURA-651 MAIN",
      "VENTURA-5851 THILLE",
      "VENTURA-2575 VISTA DEL MAR",
      "VENTURA-77 CALIFORNIA",
      "VENTURA-5600 EVERGLADES",
      "VENTURA-5777 N VENTURA",
      "VENTURA-2180 CASITAS VISTA",
      "VENTURA-1190 S VICTORIA"
    ],

    # Gerald Urias - 137554
    "137554" => [
      "CAMARILLO-1750 LEWIS",
      "CAMARILLO-1750 S LEWIS",
      "CAMARILLO-1756 LEWIS",
      "CAMARILLO-1756 S LEWIS",
      "CAMARILLO-1760 LEWIS",
      "CAMARILLO-1760 S LEWIS",
      "CAMARILLO-1758 LEWIS",
      "CAMARILLO-1758 S LEWIS",
      "CAMARILLO-333 SKYWAY",
      "CAMARILLO-3801 LAS POSAS",
      "CAMARILLO-600 AVIATION",
      "CAMARILLO-1701 SOLAR",
      "CAMARILLO-1801 SOLAR",
      "CAMARILLO-1911 WILLIAMS",
      "CAMARILLO-341 BERNOULLI",
      "VENTURA-2189 EASTMAN",
      "FILLMORE-828 W VENTURA",
      "OXNARD-2000 OUTLET CENTER",
      "OXNARD-3100 ROSE",
      "OXNARD-325 W CHANNEL ISLANDS",
      "OXNARD-2400 C STREET",
      "OXNARD-2400 S C ST",
      "OXNARD-2500 S C ST",
      "OXNARD-2643 SAVIERS",
      "OXNARD-2697 SAVIERS",
      "OXNARD-2791 PARK VIEW",
      "OXNARD-545 S A STREET",
      "OXNARD-555 S A STREET",
      "OXNARD-545 CENTRAL",
      "OXNARD-2820 JORDAN",
      "OXNARD-2820 JOURDAN",
      "OXNARD-2130 VENTURA",
      "OXNARD-2130 N VENTURA",
      "OXNARD-2901 VENTURA",
      "OXNARD-2901 N VENTURA",
      "OXNARD-1721 PACIFIC",
      "OXNARD-2420 CELSIUS",
      "OXNARD-1400 VANGUARD",
      "OXNARD-1051 YARNELL",
      "OXNARD-2220 E GONZALES",
      "OXNARD-2240 E GONZALES",
      "SANTA PAULA-254 W HARVARD",
      "SANTA PAULA-620 W HARVARD",
      "SANTA PAULA-725 E MAIN",
      "SANTA PAULA-1334 E MAIN",
      "SANTA PAULA-67 E BARNETT",
      "MOORPARK-612 SPRING RD BLDG A",
      "MOORPARK-670 W LOS ANGELES",
      "MOORPARK-670 W LA AVE",
      "MOORPARK-1133 LOS ANGELES",
      "MOORPARK-1133 E LOS ANGELES",
      "MOORPARK-1227 E LOS ANGELES",
      "THOUSAND OAKS-125 W THOUSAND OAKS",
      "PORT HUENEME-510 PARK"
    ],

    # Steve Blair - 120131
    "120131" => [
      "VENTURA-800 S VICTORIA",
      "VENTURA-1001 PARTRIDGE",
      "VENTURA-1070 HILL",
      "VENTURA-6401 TELEPHONE",
      "VENTURA-855 PARTRIDGE",
      "VENTURA-1000 HILL",
      "VENTURA-5122 RALSTON",
      "OXNARD-4353 VINEYARD",
      "SIMI VALLEY-3855 ALAMO F"
    ],

    # Nathan Paul - 128975
    "128975" => [
      "FRAZIER PARK-15031 LOCKWOOD",
      "FRAZIER PARK-15011 LOCKWOOD",
      "FRAZIER PARK-15051 LOCKWOOD"
    ]
  }.freeze

  def self.find_manager_for_location(location)
    return nil if location.blank?

    normalized_location = normalize_location(location)

    # Find the manager whose location patterns match
    LOCATION_MANAGER_MAP.each do |manager_id, patterns|
      patterns.each do |pattern|
        # Check if the pattern is a substring of the location or vice versa
        # Also check if both share significant common words (for partial matches)
        if locations_match?(normalized_location, pattern)
          return manager_id
        end
      end
    end

    nil # No match found
  end

  def self.locations_match?(location1, location2)
    # Direct substring match (most reliable)
    return true if location1.include?(location2) || location2.include?(location1)

    # For stricter matching, extract city and street address
    # Format is typically: "CITY-STREET ADDRESS"
    city1, addr1 = extract_city_and_address(location1)
    city2, addr2 = extract_city_and_address(location2)

    # Cities must match
    return false unless cities_match?(city1, city2)

    # Now check if addresses match with some flexibility
    # Extract just the numbers and main street name
    num1 = addr1.scan(/\d+/).first
    num2 = addr2.scan(/\d+/).first

    # Street numbers must match if both have them
    return false if num1 && num2 && num1 != num2

    # Check if the street names overlap significantly
    addr1_words = addr1.split.reject { |w| w.match?(/^\d+$/) || w.length < 2 }
    addr2_words = addr2.split.reject { |w| w.match?(/^\d+$/) || w.length < 2 }

    return false if addr1_words.empty? || addr2_words.empty?

    # At least 70% of the street name words should match
    shorter_words, longer_words = [addr1_words, addr2_words].sort_by(&:length)
    matches = shorter_words.count { |word| longer_words.any? { |w| w == word || w.include?(word) || word.include?(w) } }
    match_percentage = matches.to_f / shorter_words.length

    match_percentage >= 0.7
  end

  def self.extract_city_and_address(location)
    # Split on the dash that separates city from address
    parts = location.split(/\s*-\s*/, 2)
    if parts.length == 2
      [parts[0].strip, parts[1].strip]
    else
      ["", location.strip]
    end
  end

  def self.cities_match?(city1, city2)
    return true if city1 == city2
    return true if city1.empty? || city2.empty?

    # Handle abbreviations and variations
    city1 = city1.gsub(/[. ]/, "")
    city2 = city2.gsub(/[. ]/, "")

    city1 == city2 || city1.include?(city2) || city2.include?(city1)
  end

  def self.normalize_location(location)
    # Remove extra spaces, punctuation, convert to uppercase
    # This helps with fuzzy matching
    location.to_s
            .upcase
            .gsub(/[.,#&]/, " ")  # Replace punctuation with spaces
            .gsub(/\s+/, " ")     # Collapse multiple spaces
            .gsub(/\bSTREET\b/, "ST")
            .gsub(/\bAVENUE\b/, "AVE")
            .gsub(/\bROAD\b/, "RD")
            .gsub(/\bBOULEVARD\b/, "BLVD")
            .gsub(/\bDRIVE\b/, "DR")
            .gsub(/\bSUITE\b/, "STE")
            .gsub(/\bBUILDING\b/, "BLDG")
            .gsub(/\bSOUTH\b/, "S")
            .gsub(/\bNORTH\b/, "N")
            .gsub(/\bEAST\b/, "E")
            .gsub(/\bWEST\b/, "W")
            .strip
  end
end
