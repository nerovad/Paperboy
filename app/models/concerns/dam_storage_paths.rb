# frozen_string_literal: true

# The filesystem side of a Dam::StorageLocation: the folder it stores files in,
# the Active Storage service that writes there, and the folder it watches.
#
# Both folders are typed into a form, so both are held inside the folders
# PAPERBOY_DAM_ROOTS allows — set per host in .env, and the one part of this
# the UI cannot change.
module DamStoragePaths
  extend ActiveSupport::Concern

  # Kinds whose root is a directory this host can write to. Object storage and
  # the cold archive need an adapter first; until then their root is a note.
  FILESYSTEM_KINDS = %w[disk smb].freeze

  # What a scan does with the files it finds. A drop box is emptied into the
  # library; a share somebody else maintains is read where it stands, and the
  # library keeps only a proxy and a thumbnail of each file.
  INGEST_MODES = {
    'off' => 'Not scanned',
    'move' => 'Move originals into the library',
    'reference' => 'Read in place — originals are never moved or copied'
  }.freeze

  # Spellings of the same format. Somebody who types "jpg" into the format
  # list means the .jpeg beside it too, and a library where half the camera
  # output is refused because of one letter is not a library.
  FORMAT_ALIASES = {
    'JPEG' => 'JPG', 'JPE' => 'JPG', 'TIFF' => 'TIF', 'MPEG' => 'MPG',
    'HTM' => 'HTML', 'AIFF' => 'AIF', 'MIDI' => 'MID'
  }.freeze

  # dam_location_<id>_<digest of root>. The digest pins a name to one root, so
  # a service built for a name stays right for as long as the process lives.
  SERVICE_NAME = /\Adam_location_(\d+)_(\h{12})\z/

  included do
    validates :ingest_mode, inclusion: { in: INGEST_MODES.keys }
    validates :watch_path, presence: { message: 'is needed to scan a folder' },
                           if: -> { ingest_mode != 'off' }
    validates :watch_path, uniqueness: { case_sensitive: true }, allow_blank: true
    validate :root_is_usable, if: -> { own_storage? && (new_record? || will_save_change_to_root?) }
    validate :watch_path_is_usable, if: -> { watch_path.present? && will_save_change_to_watch_path? }
    validate :storage_unchanged_while_holding_files, on: :update
  end

  class_methods do
    # Where a root or watch folder may be, from PAPERBOY_DAM_ROOTS
    # (colon-separated). Read on every call, so a changed .env needs a restart
    # rather than a deploy.
    def allowed_roots
      ENV.fetch('PAPERBOY_DAM_ROOTS') { Rails.root.join('storage', 'dam', Rails.env).to_s }
         .split(File::PATH_SEPARATOR).compact_blank.map { |root| resolve_path(root) }
    end

    def allowed_path?(path)
      resolved = resolve_path(path)
      allowed_roots.any? { |root| inside?(resolved, root) }
    end

    # Symlinks are followed where the path exists, so a link inside an allowed
    # root cannot lead back out of one.
    def resolve_path(path)
      expanded = File.expand_path(path.to_s)
      File.exist?(expanded) ? File.realpath(expanded) : expanded
    end

    def inside?(path, root) = path == root || path.start_with?("#{root.chomp('/')}/")

    # One spelling per format, so a list and a filename can be compared.
    def canonical_format(format)
      upcased = format.to_s.delete('.').upcase
      FORMAT_ALIASES.fetch(upcased, upcased)
    end

    def overlap?(one, other) = inside?(one, other) || inside?(other, one)

    # The Active Storage service behind a dam_location_* name, or nil when no
    # location answers to it. Reads never check the allowlist: files already
    # stored stay readable after PAPERBOY_DAM_ROOTS is narrowed.
    def service_for(name)
      match = SERVICE_NAME.match(name.to_s)
      location = match && find_by(id: match[1])
      return nil unless location && location.storage_service_name == name.to_s

      ActiveStorage::Service::DiskService.new(root: File.expand_path(location.root)).tap do |service|
        service.name = name.to_s
      end
    end
  end

  def ingest_mode_label = INGEST_MODES.fetch(ingest_mode, ingest_mode.to_s.titleize)

  def scanning? = ingest_mode != 'off' && watch_path.present?

  def moves_originals? = ingest_mode == 'move'

  def references_originals? = ingest_mode == 'reference'

  # Formats this location takes, upcased and without dots, as Dam::Asset
  # stores them. Empty means everything.
  def accepted_format_list
    accepted_formats.to_s.split(/[,\s]+/).filter_map { |format| format.delete('.').upcase.presence }
  end

  # Filename globs this location passes over. ResourceSpace writes five
  # previews beside each original, and nobody wants those as assets.
  def ignore_pattern_list
    ignore_patterns.to_s.split(',').filter_map { |pattern| pattern.strip.presence }
  end

  # Whether this location may read a file from a path — the check a download
  # does before sending anything.
  #
  # The boundary is PAPERBOY_DAM_ROOTS, not the folder this location scans: an
  # imported asset's original often sits somewhere else entirely, the way
  # ResourceSpace keeps its catalogue in one place and the files it describes
  # in another. The allowed roots are set per host in .env and cannot be
  # changed from inside the app, which is what makes them the boundary worth
  # having; a source_path is a column, and columns are written by code.
  def holds_source?(path) = self.class.allowed_path?(path)

  def ignored_filename?(filename)
    ignore_pattern_list.any? { |pattern| File.fnmatch?(pattern, filename.to_s, File::FNM_CASEFOLD) }
  end

  def accepts_format?(format)
    list = accepted_format_list
    return true if list.empty?

    list.map { |entry| self.class.canonical_format(entry) }
        .include?(self.class.canonical_format(format))
  end

  def filesystem? = FILESYSTEM_KINDS.include?(kind)

  # Whether this location stores files in its own root rather than in the
  # app's default Active Storage service.
  def own_storage? = filesystem? && root.present?

  # What Dam::Asset attaches through. nil means the default service.
  def storage_service_name = service_name_for(kind, root)

  # Where new files here actually land, for the Storage screen.
  def storage_path
    return File.expand_path(root) if own_storage?

    service = ActiveStorage::Blob.service
    service.respond_to?(:root) ? service.root.to_s : nil
  end

  # Whether any stored file is held by this location's own service. Those files
  # are found by service name alone, so they keep this location's root pinned
  # even after their assets have been moved elsewhere.
  def holds_own_files?
    return false if id.blank?

    prefix = "#{self.class.sanitize_sql_like("dam_location_#{id}_")}%"
    ActiveStorage::Blob.where(ActiveStorage::Blob.arel_table[:service_name].matches(prefix, '\\')).exists?
  end

  private

  def service_name_for(kind, root)
    return nil unless FILESYSTEM_KINDS.include?(kind) && root.present? && id.present?

    "dam_location_#{id}_#{Digest::SHA256.hexdigest(File.expand_path(root))[0, 12]}"
  end

  def root_is_usable
    check_folder(:root, root)
    overlapping = self.class.where.not(id: id).where.not(watch_path: [nil, ''])
                      .find { |other| self.class.overlap?(resolved(root), resolved(other.watch_path)) }
    errors.add(:root, "overlaps #{overlapping.label}'s watch folder") if overlapping
  end

  # A watch folder is emptied into the library, so it must never be — or
  # contain, or sit inside — a folder the library itself writes to.
  def watch_path_is_usable
    check_folder(:watch_path, watch_path)
    return if errors.include?(:watch_path)

    watched = resolved(watch_path)
    stores = self.class.where.not(id: id).to_a.push(self).filter_map(&:storage_path)
    errors.add(:watch_path, 'overlaps a folder the library stores files in') if
      stores.any? { |store| self.class.overlap?(watched, resolved(store)) }

    clash = self.class.where.not(id: id).where.not(watch_path: [nil, ''])
                .find { |other| self.class.overlap?(watched, resolved(other.watch_path)) }
    errors.add(:watch_path, "overlaps #{clash.label}'s watch folder") if clash
  end

  # Inside the allowlist, then created if missing and writable by this process.
  # Creating it here is deliberate: the admin just asked for it, and the next
  # upload or sweep would otherwise be the first to find out it is not there.
  def check_folder(attribute, path)
    allowed = self.class.allowed_roots.to_sentence
    return errors.add(attribute, "must be inside #{allowed}") unless self.class.allowed_path?(path)

    FileUtils.mkdir_p(path)
    errors.add(attribute, 'is not writable by the app') unless File.writable?(path)
  rescue SystemCallError => e
    errors.add(attribute, "cannot be created (#{e.message})")
  end

  def resolved(path) = self.class.resolve_path(path)

  # A stored file is found again through its service name. Changing the root or
  # the kind would give this location a new name and orphan every file under
  # the old one, so that waits until those files have been moved off.
  def storage_unchanged_while_holding_files
    return unless will_save_change_to_root? || will_save_change_to_kind?
    return if service_name_for(kind_in_database, root_in_database) == storage_service_name
    return unless holds_own_files?

    errors.add(:root, 'cannot change while files are stored under the current one')
  end
end
