# frozen_string_literal: true

# lib/tasks/dam.rake
namespace :dam do
  # Storage locations and metadata fields are reference data, not user content:
  # Advanced Search builds its Storage facet and its custom-criteria field
  # picker from these tables, so an empty install has an Advanced Search modal
  # with two sections that say "nothing configured yet".
  #
  # Idempotent — run it again after adding an entry below and only the new rows
  # appear. Existing rows are left alone so local edits survive.
  desc 'Seed the DAM reference data Advanced Search is built from (idempotent)'
  task seed_reference_data: :environment do
    storage = [
      { key: 'local_disk', label: 'Local disk', kind: 'disk', position: 1,
        description: "The app's own Active Storage folder. Give it a root to store files elsewhere.",
        default_for_uploads: true },
      # Read-only from the start: an archive is where things are moved to, not
      # somewhere an ingest form should offer to drop a new upload.
      { key: 'archive', label: 'Cold archive', kind: 'archive',
        description: 'Long-term retention. Restores are not instant.', position: 2,
        read_only: true }
    ]

    fields = [
      { key: 'campaign', label: 'Campaign', field_type: 'text', position: 1,
        description: 'Project or campaign the asset was produced for.' },
      { key: 'usage_rights', label: 'Usage rights', field_type: 'select', position: 2,
        description: 'Who may use this, and where.',
        options: ['Internal only', 'Public', 'Embargoed', 'Rights expired'].to_json },
      { key: 'photographer', label: 'Photographer / creator', field_type: 'text', position: 3 },
      { key: 'location', label: 'Location', field_type: 'text', position: 4 },
      { key: 'captured_on', label: 'Captured on', field_type: 'date', position: 5,
        description: 'When the shot was taken, which is rarely when it was ingested.' },
      { key: 'rating', label: 'Rating', field_type: 'number', position: 6,
        description: '1 to 5. Numeric so "rating over 3" is a range, not a string match.' },
      { key: 'release_on_file', label: 'Release on file', field_type: 'select', position: 7,
        options: %w[Yes No Unknown].to_json }
    ]

    created = { storage: 0, fields: 0 }

    storage.each do |attributes|
      next if Dam::StorageLocation.exists?(key: attributes[:key])

      Dam::StorageLocation.create!(attributes)
      created[:storage] += 1
    end

    fields.each do |attributes|
      next if Dam::MetadataField.exists?(key: attributes[:key])

      Dam::MetadataField.create!(attributes)
      created[:fields] += 1
    end

    puts "Storage locations: #{created[:storage]} added, #{Dam::StorageLocation.count} total."
    puts "Metadata fields:   #{created[:fields]} added, #{Dam::MetadataField.count} total."
    puts 'Both now appear as facets in the DAM Advanced Search modal.'
    puts "Uploads default to: #{Dam::StorageLocation.library_default&.label || 'nowhere — no location is accepting uploads'}."
  end

  desc 'Scan every DAM storage location that has a folder to ingest from'
  task ingest_watch_folders: :environment do
    Dam::StorageLocation.scanning.ordered.each do |location|
      result = Dam::WatchFolderIngest.for_location(location).call
      puts "#{location.label} (#{location.watch_path}, #{location.ingest_mode}): " \
           "#{result.ingested} ingested, #{result.failed} failed, #{result.skipped} already held"
    end
    puts 'No location is scanning a folder.' if Dam::StorageLocation.scanning.none?
  end

  # Leaving ResourceSpace is two steps on two servers, so the server the DAM
  # runs on never has to reach ResourceSpace's database.
  #
  # 1. On the ResourceSpace server (needs the optional resourcespace gem group
  #    and RS_DB_* in .env) — writes a bundle folder of about 4.5GB:
  #
  #      OUT=/srv/rs-export bundle exec rails dam:export_resourcespace
  #
  # 2. Copy that folder to the DAM's server (rsync -a is resumable), then:
  #
  #      BUNDLE=/srv/rs-export LOCATION=resourcespace \
  #      SYNC_BASE=/mnt/i/BUSINESS_SUPPORT/Graphics_Dept/Visual_Assets_Stock_Photos_Vector_Art \
  #      DRY_RUN=1 bundle exec rails dam:import_resourcespace
  #
  # SYNC_BASE is where ResourceSpace's relative file paths hang off, as mounted
  # on the DAM's server. Originals found there are referenced, not copied; the
  # ones ResourceSpace kept in its own filestore travel inside the bundle and
  # are stored in the DAM.
  desc 'Write a ResourceSpace library to a folder for dam:import_resourcespace (OUT=, LIMIT=)'
  task export_resourcespace: :environment do
    out = ENV.fetch('OUT') { abort 'Set OUT to the folder to write the export into.' }
    progress = ->(stats) { puts "  #{stats.resources} resources so far…" }
    puts "Exporting ResourceSpace to #{out}"
    stats = Dam::ResourceSpace::Export.new(out: out, limit: ENV['LIMIT']&.to_i, progress: progress).call
    puts stats
    puts "Copy #{out} to the DAM's server and run dam:import_resourcespace there."
  end

  desc 'Import a ResourceSpace export as DAM assets (BUNDLE=, LOCATION=, SYNC_BASE=, DRY_RUN=1, LIMIT=)'
  task import_resourcespace: :environment do
    location = Dam::StorageLocation.find_by(key: ENV.fetch('LOCATION', 'resourcespace'))
    abort "No storage location with key #{ENV.fetch('LOCATION', 'resourcespace')}" if location.nil?

    bundle = Dam::ResourceSpace::Bundle.new(ENV.fetch('BUNDLE') { abort 'Set BUNDLE to the export folder.' })
    puts "Export of #{bundle.resources.size} resources, written #{bundle.exported_at}"
    puts "Importing into #{location.label}#{' — dry run' if ENV['DRY_RUN']}"

    import = Dam::ResourceSpace::Import.new(location: location, bundle: bundle,
                                            sync_base: ENV.fetch('SYNC_BASE', nil),
                                            limit: ENV['LIMIT']&.to_i, dry_run: ENV['DRY_RUN'].present?)
    puts import.call

    import.failures.first(10).each { |failure| puts "  failed #{failure[:ref]}: #{failure[:error]}" }
    next if import.unresolved.empty?

    puts "\nFirst #{[import.unresolved.size, 25].min} resources whose original could not be found:"
    import.unresolved.first(25).each { |row| puts "  #{row[:ref]}\t#{row[:path]}" }
    puts 'These are paths relative to SYNC_BASE. Check that the share is mounted here.'
  end

  # After installing ImageMagick, ffmpeg or poppler-utils on a host that was
  # missing them — every asset whose proxy could not be built is queued again.
  # STATE=failed, pending, or both (the default). ID=12,13 for particular ones.
  desc 'Queue proxy and thumbnail builds for assets that have none'
  task rebuild_derivatives: :environment do
    scope = Dam::Asset.where(derivative_state: ENV.fetch('STATE', 'pending,failed').split(','))
    scope = scope.where(id: ENV['ID'].split(',')) if ENV['ID'].present?

    queued = 0
    scope.find_each do |asset|
      Dam::BuildDerivativesJob.perform_later(asset.id)
      queued += 1
    end
    puts "Queued #{queued} #{'asset'.pluralize(queued)}."
    counted = Dam::Asset.group(:derivative_state).count
    puts(counted.map { |state, held| "  #{state}: #{held}" })
    puts 'Nothing runs until Solid Queue does — check the jobs service on this host.' if queued.positive?
  end
end
