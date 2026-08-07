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
      { key: 'local_disk', label: 'Local disk', kind: 'disk', root: Rails.root.join('storage').to_s,
        description: 'Active Storage service backing ingested files.', position: 1 },
      { key: 'archive', label: 'Cold archive', kind: 'archive',
        description: 'Long-term retention. Restores are not instant.', position: 2 }
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
  end
end
