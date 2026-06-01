class Building < GsabssBase
  self.primary_key = "id"

  # site_description values that surface as "Locations" in the Authorization
  # Console. SQL Server's default collation matches these case-insensitively.
  AUTH_CONSOLE_SITE_DESCRIPTIONS = %w[Office Administration].freeze

  scope :for_authorization_console, -> {
    where(site_description: AUTH_CONSOLE_SITE_DESCRIPTIONS)
      .where.not(occupant_description: [nil, ""])
  }

  # "occupant_description - address". Buildings without an occupant are excluded
  # by the for_authorization_console scope, so occupant is always present here.
  def location_label
    [occupant_description, address.presence].compact.join(" - ")
  end
end
