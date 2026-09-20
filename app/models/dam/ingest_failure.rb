# frozen_string_literal: true

module Dam
  # One file a scan could not ingest, remembered so the next scan does not try
  # it again. Without this a tree with a handful of unreadable files writes a
  # fresh batch of failed jobs on every pass, for as long as they sit there.
  #
  # Remembered by the digest of the path, the same key an asset records, so a
  # file that is later fixed in place is retried once #forget has dropped it.
  class IngestFailure < ApplicationRecord
    belongs_to :storage_location, class_name: 'Dam::StorageLocation',
                                  foreign_key: :storage_location_id, inverse_of: :ingest_failures

    validates :source_key, presence: true, uniqueness: { scope: :storage_location_id }

    scope :newest_first, -> { order(last_failed_at: :desc) }

    # Records the failure, or counts another attempt against one already
    # recorded, so the row says how long something has been failing.
    def self.remember(location:, path:, key:, reason:)
      failure = find_or_initialize_by(storage_location_id: location.id, source_key: key)
      failure.attempts = failure.persisted? ? failure.attempts + 1 : 1
      failure.assign_attributes(source_path: path.to_s, reason: reason.to_s.truncate(2000),
                                last_failed_at: Time.current)
      failure.save!
      failure
    end

    def self.keys_for(location, keys)
      where(storage_location_id: location.id, source_key: keys).pluck(:source_key)
    end
  end
end
