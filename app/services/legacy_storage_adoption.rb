# frozen_string_literal: true

# Copies the files this database's blobs reference out of the shared, pre-split
# storage/ folder into this environment's own Active Storage root.
#
# Copies rather than moves: dev, stage and prod all read the legacy folder
# until each has run this, and a database restored from another environment
# can reference the same keys. Idempotent — a file already in place is left
# alone, so every deploy can run it.
class LegacyStorageAdoption
  Result = Struct.new(:copied, :present, :missing, keyword_init: true)

  def initialize(legacy_root: Rails.root.join('storage'),
                 service: ActiveStorage::Blob.services.fetch(:local))
    @legacy_root = Pathname(legacy_root)
    @service = service
  end

  def call
    result = Result.new(copied: 0, present: 0, missing: [])
    return result if same_root?

    ActiveStorage::Blob.where(service_name: 'local').find_each do |blob|
      adopt(blob.key, result)
    end
    result
  end

  private

  def adopt(key, result)
    target = Pathname(@service.path_for(key))
    source = @legacy_root.join(key[0..1], key[2..3], key)

    if target.exist?
      result.present += 1
    elsif source.file?
      FileUtils.mkdir_p(target.dirname)
      FileUtils.cp(source, target, preserve: true)
      result.copied += 1
    else
      result.missing << key
    end
  end

  def same_root?
    File.expand_path(@service.root) == File.expand_path(@legacy_root)
  end
end
