# frozen_string_literal: true

module Dam
  # Writes custom metadata onto an asset from a { field_key => value } hash.
  #
  # A blank value clears the row rather than storing an empty string, so an
  # "is blank" filter in Advanced Search stays honest. Keys nothing is
  # configured for are dropped: the form and an import both hand over whatever
  # they were given, and neither should be able to invent a field.
  class MetadataAssignment
    def self.apply(asset, submitted)
      new(asset, submitted).apply
    end

    def initialize(asset, submitted)
      @asset = asset
      @submitted = submitted
    end

    def apply
      return @asset if @submitted.blank?

      values.each { |key, value| assign(key, value.to_s.strip) }
      @asset
    end

    private

    def values
      allowed = Dam::MetadataField.active.pluck(:key)
      hash = @submitted.respond_to?(:to_unsafe_h) ? @submitted.to_unsafe_h : @submitted.to_h
      hash.stringify_keys.slice(*allowed)
    end

    def assign(key, value)
      row = @asset.metadata_values.find { |candidate| candidate.field_key == key }

      if value.blank?
        row&.mark_for_destruction
      elsif row
        row.value = value
      else
        @asset.metadata_values.build(field_key: key, value: value)
      end
    end
  end
end
