# frozen_string_literal: true

module Dam
  # A named, ordered grouping of assets. Nests via parent_id.
  class Collection < ApplicationRecord
    include DamDashboardSubject

    belongs_to :parent, class_name: 'Dam::Collection', optional: true
    has_many :children, class_name: 'Dam::Collection', foreign_key: :parent_id,
                        dependent: :nullify, inverse_of: :parent

    has_many :collection_assets, class_name: 'Dam::CollectionAsset', dependent: :destroy,
                                 foreign_key: :collection_id, inverse_of: :collection
    has_many :assets, through: :collection_assets, source: :asset

    validates :name, presence: true

    scope :roots, -> { where(parent_id: nil) }
    scope :newest_first, -> { order(created_at: :desc) }
    scope :alphabetical, -> { order(:name) }

    def to_s = name

    # Assets in curated order, ready to render as a contact sheet.
    def ordered_assets
      assets.merge(Dam::CollectionAsset.order(:position, :id))
    end

    def asset_count = collection_assets.count

    # The first image in the collection, used as its card thumbnail. Falls back
    # to nothing rather than to a non-image, which would render as a broken
    # <img> in the grid.
    def cover_asset
      ordered_assets.find { |asset| asset.image? && asset.file.attached? }
    end

    # Ancestors nearest-last, for the breadcrumb on a nested collection. Guards
    # against a cycle rather than trusting the data, since parent_id is
    # editable.
    def ancestors
      chain = []
      node = parent
      while node && chain.size < 10 && chain.exclude?(node)
        chain.unshift(node)
        node = node.parent
      end
      chain
    end
  end
end
