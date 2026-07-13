# frozen_string_literal: true

class Building < GsabssBase
  self.primary_key = 'id'

  # site_description values that surface as "Locations" in the Authorization
  # Console. SQL Server's default collation matches these case-insensitively.
  AUTH_CONSOLE_SITE_DESCRIPTIONS = %w[Office Administration].freeze

  # Office/Administration buildings, plus any building hand-tagged with a
  # short_name (curated selectable sites whose real site type may be something
  # else, e.g. the Hall of Justice / PTDF on the Government Center campus).
  scope :for_authorization_console, lambda {
    where('site_description IN (?) OR short_name IS NOT NULL', AUTH_CONSOLE_SITE_DESCRIPTIONS)
      .where.not(occupant_description: [nil, ''])
  }

  # "occupant_description - address". Buildings without an occupant are excluded
  # by the for_authorization_console scope, so occupant is always present here.
  def location_label
    [occupant_description, address.presence].compact.join(' - ')
  end
end
