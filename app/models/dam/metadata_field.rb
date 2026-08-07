# frozen_string_literal: true

module Dam
  # A custom metadata field assets can carry. Populates the field picker in the
  # Advanced Search modal and the metadata editor on an asset.
  class MetadataField < ApplicationRecord
    FIELD_TYPES = %w[text number date select].freeze

    # Which comparisons the modal offers, per field type. Anything not listed
    # here is not a legal operator — Dam::AssetSearch checks against this.
    OPERATORS = {
      'text' => %w[contains equals starts_with not_contains present blank],
      'number' => %w[equals greater_than less_than between present blank],
      'date' => %w[on before after between present blank],
      'select' => %w[equals not_equals present blank]
    }.freeze

    validates :key, presence: true, uniqueness: { case_sensitive: false }
    validates :label, presence: true
    validates :field_type, inclusion: { in: FIELD_TYPES }

    scope :active, -> { where(active: true) }
    scope :ordered, -> { order(:position, :label) }

    def operators = OPERATORS.fetch(field_type, OPERATORS['text'])

    # Parsed choices for a select field. Stored as JSON text so adding a choice
    # does not need a migration.
    def choices
      return [] unless field_type == 'select' && options.present?

      Array(JSON.parse(options))
    rescue JSON::ParserError
      []
    end
  end
end
