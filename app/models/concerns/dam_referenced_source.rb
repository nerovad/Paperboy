# frozen_string_literal: true

# An asset whose file the library does not own, and the copies it shows in its
# place.
#
# A stored asset's bytes ride on Active Storage. A referenced one names a file
# on a share that is read and never copied — 25GB of somebody else's filestore
# should not become 50GB because the DAM catalogued it — so what the library
# holds of it is a proxy and a thumbnail, and nothing else.
module DamReferencedSource
  extend ActiveSupport::Concern

  # Where the bytes are. A stored asset's file rides on Active Storage; a
  # referenced one is a file on a share the library reads and never copies,
  # so all it holds here is the proxy and the thumbnail.
  STORAGE_KINDS = %w[stored referenced].freeze

  # Whether the viewable copies have been built yet. 'none' is for the
  # formats nothing can usefully draw.
  DERIVATIVE_STATES = %w[pending ready failed none].freeze

  class_methods do
    # Symlinks resolved where the file is there, so the same file reached by
    # two paths is one key — and a file that vanished mid-scan still keys the
    # same way it did when it was read.
    def source_key_for(path)
      pathname = Pathname(path)
      resolved = pathname.exist? ? pathname.realpath : pathname.expand_path
      Digest::SHA256.hexdigest(resolved.to_s)
    end
  end

  included do
    # What the library shows: a web-sized proxy and a grid thumbnail. Both are
    # built by Dam::DerivativeBuilder, and both are small, so a referenced
    # asset costs the library kilobytes rather than the original's megabytes.
    has_one_attached :proxy, service: ->(asset) { asset.storage_location&.storage_service_name }
    has_one_attached :thumbnail, service: ->(asset) { asset.storage_location&.storage_service_name }

    # What a grid needs to draw a card: the thumbnail, and the stored file it
    # falls back to while one is still being built.
    scope :with_previews, -> { with_attached_file.with_attached_thumbnail }

    scope :without_previews, -> { where(derivative_state: %w[pending failed]) }

    validates :storage_kind, inclusion: { in: STORAGE_KINDS }
    validates :derivative_state, inclusion: { in: DERIVATIVE_STATES }
    validates :source_path, presence: true, if: :referenced?
  end

  def referenced? = storage_kind == 'referenced'

  def stored? = storage_kind == 'stored'

  # Fills the derived columns from a file on a share, for an asset that
  # references it rather than taking a copy.
  def apply_reference_facts!(path, content_type: nil)
    pathname = Pathname(path)
    self.storage_kind = 'referenced'
    self.source_path = pathname.to_s
    self.source_key = self.class.source_key_for(pathname)
    self.content_type = content_type || Marcel::MimeType.for(pathname, name: pathname.basename.to_s)
    self.filename ||= pathname.basename.to_s
    self.title = filename.to_s.sub(/\.[^.]+\z/, '').tr('_-', '  ').squish if title.blank?
    self.format = pathname.extname.delete('.').upcase.presence
    self.media_type = self.class.media_type_for(self.content_type, format)
    self.byte_size = pathname.size
    self.ingested_at ||= Time.current
  end

  # The original as a readable path, or nil when the share is not mounted or
  # the file has been moved out from under us.
  def original_path
    return nil if source_path.blank?

    path = Pathname(source_path)
    path.file? && path.readable? ? path : nil
  end

  def original_available? = referenced? ? original_path.present? : file.attached?
end
