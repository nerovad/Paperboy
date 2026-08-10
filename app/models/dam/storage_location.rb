# frozen_string_literal: true

module Dam
  # A place asset bytes live, and — since uploads have to land somewhere — a
  # place they can be sent.
  #
  # A DAM outlives any one backend: files start on a share, move to object
  # storage, and old masters end up somewhere cheap and slow. So a location is
  # a record with a lifecycle rather than a path prefix, and "is it still
  # taking uploads" is a fact about it, not a guess from its name.
  class StorageLocation < ApplicationRecord
    GIGABYTE = 1_073_741_824

    # How an adapter reaches it, not where it is.
    KINDS = {
      'disk' => 'Local disk',
      's3' => 'Object storage',
      'smb' => 'Network share',
      'archive' => 'Cold archive'
    }.freeze

    has_many :assets, class_name: 'Dam::Asset', dependent: :nullify,
                      foreign_key: :storage_location_id, inverse_of: :storage_location

    validates :key, presence: true, uniqueness: { case_sensitive: false }
    validates :label, presence: true
    validates :kind, inclusion: { in: KINDS.keys }
    validates :quota_bytes, numericality: { greater_than: 0, allow_nil: true }

    before_validation :derive_key, on: :create
    before_validation :place_last, on: :create
    before_destroy :keep_locations_still_holding_assets, prepend: true
    after_save :demote_the_others, if: -> { default_for_uploads? && saved_change_to_default_for_uploads? }

    scope :active, -> { where(active: true) }
    scope :ordered, -> { order(:position, :label) }
    # Everywhere an upload could actually land. Read-only is the case `active`
    # cannot express: still readable, still searchable, closed to new bytes.
    scope :uploadable, -> { active.where(read_only: false) }

    # Where this person's next upload goes if the ingest form does not say.
    # Their own choice first, then the library default, then whatever will
    # have it — so an install that has configured nothing still ingests.
    def self.for_upload_by(employee_id)
      chosen = uploadable.find_by(id: UserSetting.dam_storage_location_id_for(employee_id))
      chosen || library_default
    end

    # The marked default, but only while it is still able to take uploads:
    # disabling a location is enough to route around it, without anyone having
    # to remember to move the flag first.
    def self.library_default
      uploadable.find_by(default_for_uploads: true) || uploadable.ordered.first
    end

    # What a Storage picker may offer. `current` is whatever the record being
    # edited already points at: it stays on the list even when it is closed, or
    # saving the form would quietly move an asset out of a read-only archive.
    def self.upload_options_for(current = nil)
      options = uploadable.ordered.to_a
      options.unshift(current) if current && options.exclude?(current)
      options
    end

    def to_s = label

    def kind_label = KINDS.fetch(kind, kind.to_s.titleize)

    def accepts_uploads?(used = used_bytes) = refusal_reason(used).nil?

    def asset_count = assets.count

    def used_bytes = assets.sum(:byte_size).to_i

    # The usage figures all take the total as an argument so a table listing
    # every location can pass one grouped SUM instead of one query per row.
    def usage_percent(used = used_bytes)
      return nil if quota_bytes.to_i.zero?

      [(used.to_i.to_f / quota_bytes * 100).round, 100].min
    end

    def full?(used = used_bytes)
      quota_bytes.to_i.positive? && used.to_i >= quota_bytes
    end

    # Why this location will not take an upload, or nil when it will. One
    # method so the picker, the validation and the status pill cannot disagree
    # about what "closed" means.
    def refusal_reason(used = used_bytes)
      return 'disabled' unless active?
      return 'read-only' if read_only?
      return 'at capacity' if full?(used)

      nil
    end

    # Capacity is entered and read in gigabytes; only the column is in bytes.
    def quota_gb
      return nil if quota_bytes.blank?

      (quota_bytes.to_f / GIGABYTE).round(2)
    end

    def quota_gb=(value)
      gigabytes = value.to_s.strip.to_f
      # Blank or zero means "not measured" rather than "a quota of nothing",
      # which is also how you clear one that was set by mistake.
      self.quota_bytes = gigabytes.positive? ? (gigabytes * GIGABYTE).round : nil
    end

    private

    def derive_key
      self.key = label.to_s.parameterize(separator: '_') if key.blank?
    end

    def place_last
      self.position = (self.class.maximum(:position) || 0) + 1 if position.to_i.zero?
    end

    # Kept true by the last write rather than by a validation, so ticking the
    # box on a second location moves the default instead of refusing to save.
    def demote_the_others
      self.class.where.not(id: id).where(default_for_uploads: true)
          .update_all(default_for_uploads: false, updated_at: Time.current)
    end

    # Deleting a location its assets still point at would strand them with no
    # record of where they used to be. Move them first — the location's own
    # page does it in one action.
    def keep_locations_still_holding_assets
      held = assets.count
      return if held.zero?

      errors.add(:base, "#{label} still holds #{held} #{'asset'.pluralize(held)}. " \
                        'Move them to another location before removing it.')
      throw :abort
    end
  end
end
