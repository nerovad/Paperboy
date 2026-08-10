# frozen_string_literal: true

module Dam
  # A managed file plus the metadata the DAM searches it by.
  #
  # The bytes ride on Active Storage; everything on this row is the searchable
  # projection of them. Technical facts (media type, format, dimensions) are
  # derived once at ingest by #apply_file_facts! rather than read back off
  # storage, because a grid of 200 thumbnails must not open 200 files.
  class Asset < ApplicationRecord
    include DamDashboardSubject

    MEDIA_TYPES = %w[image video document audio other].freeze
    STATUSES = %w[active processing failed archived].freeze

    # Media type inferred from the MIME type's top-level part, with the
    # document families that do not announce themselves that way spelled out.
    DOCUMENT_CONTENT_TYPES = %w[
      application/pdf
      application/msword
      application/rtf
      text/plain
      text/csv
    ].freeze

    has_one_attached :file

    belongs_to :storage_location, class_name: 'Dam::StorageLocation', optional: true

    has_many :metadata_values, class_name: 'Dam::MetadataValue', dependent: :destroy,
                               foreign_key: :asset_id, inverse_of: :asset
    has_many :collection_assets, class_name: 'Dam::CollectionAsset', dependent: :destroy,
                                 foreign_key: :asset_id, inverse_of: :asset
    has_many :collections, through: :collection_assets, source: :collection

    accepts_nested_attributes_for :metadata_values, allow_destroy: true

    validates :title, presence: true
    validates :media_type, inclusion: { in: MEDIA_TYPES }
    validates :status, inclusion: { in: STATUSES }
    validate :storage_target_accepts_uploads, on: :create

    scope :newest_first, -> { order(created_at: :desc) }
    scope :visible, -> { where(status: %w[active processing]) }
    scope :uploaded_by, ->(employee_id) { where(uploaded_by_id: employee_id.to_s) }

    # Distinct facet values, for the Advanced Search selects. Kept here rather
    # than in the search service so the modal and the query agree on what
    # "every format in the library" means.
    def self.formats_in_use
      where.not(format: [nil, '']).distinct.order(:format).pluck(:format)
    end

    def self.media_types_in_use
      where.not(media_type: [nil, '']).distinct.order(:media_type).pluck(:media_type)
    end

    # Uploaders as [id, name] pairs. Names are snapshots taken at upload, so
    # this needs no GSABSS round trip.
    def self.uploaders
      pairs = where.not(uploaded_by_id: [nil, '']).distinct.pluck(:uploaded_by_id, :uploaded_by_name)
      pairs.sort_by { |_id, name| name.to_s.downcase }
    end

    # Fills in the derived columns from an attached (or about-to-be-attached)
    # upload. Called at ingest; safe to re-run when a file is replaced.
    def apply_file_facts!(upload)
      self.filename ||= upload.original_filename
      self.title = filename.to_s.sub(/\.[^.]+\z/, '').tr('_-', '  ').squish if title.blank?
      self.content_type = upload.content_type.presence || 'application/octet-stream'
      self.format = File.extname(upload.original_filename.to_s).delete('.').upcase.presence
      self.media_type = self.class.media_type_for(content_type, format)
      self.byte_size = upload.size if upload.respond_to?(:size)
      self.ingested_at ||= Time.current
    end

    def self.media_type_for(content_type, format = nil)
      return 'document' if DOCUMENT_CONTENT_TYPES.include?(content_type)

      case content_type.to_s.split('/').first
      when 'image' then 'image'
      when 'video' then 'video'
      when 'audio' then 'audio'
      else format.to_s.casecmp('pdf').zero? ? 'document' : 'other'
      end
    end

    def image? = media_type == 'image'

    # Human file size for the grid. Rails' number_to_human_size lives in a view
    # helper; assets are rendered from several places, so it is exposed here.
    def display_size
      return nil if byte_size.blank?

      ActiveSupport::NumberHelper.number_to_human_size(byte_size)
    end

    def dimensions
      return nil if width.blank? || height.blank?

      "#{width} × #{height}"
    end

    # Custom metadata as a plain hash, for detail views and workflow payloads.
    def metadata_hash
      metadata_values.to_h { |value| [value.field_key, value.display_value] }
    end

    private

    # Checked at the door rather than only hidden from the picker: a sealed
    # archive or a full share can be reached by a stale form or a re-post, and
    # the point of closing one is that nothing new arrives in it. Create only —
    # editing an asset that already lives somewhere closed must still work.
    def storage_target_accepts_uploads
      return if storage_location.blank?

      reason = storage_location.refusal_reason
      return if reason.nil?

      errors.add(:storage_location, "#{storage_location.label} is #{reason} and cannot take new uploads")
    end
  end
end
