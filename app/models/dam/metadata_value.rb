# frozen_string_literal: true

module Dam
  # One custom metadata value on one asset.
  #
  # Writing through #value= keeps the typed columns in step with the string
  # one, so a filter can compare numbers as numbers without the caller having
  # to know which column its field lands in.
  class MetadataValue < ApplicationRecord
    # Years SQL Server's datetime will hold. Outside them the insert fails
    # outright rather than storing anything.
    STORABLE_YEARS = (1753..9999)

    belongs_to :asset, class_name: 'Dam::Asset', inverse_of: :metadata_values

    validates :field_key, presence: true

    before_save :derive_typed_columns

    def field
      @field ||= Dam::MetadataField.find_by(key: field_key)
    end

    def label = field&.label || field_key.to_s.titleize

    def display_value = value.presence

    private

    # A value that parses as a number is stored in both places: the string for
    # display and exact matching, the typed column for ranges.
    #
    # A date is parsed only for a date field. Time.zone.parse finds a date in
    # almost any text — "california, Julie Campbell…" is 1 July,
    # "iStock-1142533480.jpg" is the year 1142533480 — so parsing every value
    # filled the date filters with nonsense and made SQL Server refuse the rows
    # it could not hold.
    def derive_typed_columns
      self.numeric_value = Float(value, exception: false)
      self.date_value = field&.field_type == 'date' ? parse_date : nil
    end

    def parse_date
      return nil if value.blank?
      # Bare integers parse as dates under some formats ("2024" => Jan 2024),
      # which would make every rating look like a year.
      return nil if value.match?(/\A-?\d+(\.\d+)?\z/)

      parsed = Time.zone.parse(value)
      parsed if parsed && STORABLE_YEARS.cover?(parsed.year)
    rescue ArgumentError
      nil
    end
  end
end
