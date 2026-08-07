# frozen_string_literal: true

module Dam
  # A place asset bytes live. Referenced by assets and offered as a facet in
  # Advanced Search.
  class StorageLocation < ApplicationRecord
    KINDS = %w[disk s3 smb archive].freeze

    has_many :assets, class_name: 'Dam::Asset', dependent: :nullify,
                      foreign_key: :storage_location_id, inverse_of: :storage_location

    validates :key, presence: true, uniqueness: { case_sensitive: false }
    validates :label, presence: true
    validates :kind, inclusion: { in: KINDS }

    scope :active, -> { where(active: true) }
    scope :ordered, -> { order(:position, :label) }

    def to_s = label
  end
end
