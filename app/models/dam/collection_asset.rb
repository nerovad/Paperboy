# frozen_string_literal: true

module Dam
  # Join row placing one asset at one position in one collection.
  class CollectionAsset < ApplicationRecord
    # Membership is a fact with a date, not something that gets edited.
    self.record_timestamps = false

    belongs_to :collection, class_name: 'Dam::Collection', inverse_of: :collection_assets
    belongs_to :asset, class_name: 'Dam::Asset', inverse_of: :collection_assets

    # Uniqueness is enforced by the unique index alone, not by a validation.
    # Adding an asset that is already in the collection has to be a silent
    # no-op (the button is reached from grids whose state may be stale), and
    # create_or_find_by! delivers that by rescuing RecordNotUnique — a model
    # validation would raise RecordInvalid first and never let it through.

    before_validation :set_defaults, on: :create

    private

    def set_defaults
      self.created_at ||= Time.current
      self.position = (collection&.collection_assets&.maximum(:position) || 0) + 1 if position.blank? || position.zero?
    end
  end
end
