# frozen_string_literal: true

# lib/tasks/storage.rake
namespace :storage do
  # Each environment keeps its uploads under its own root (config/storage.yml).
  # Uploads from before that split sit directly in storage/; this copies the
  # ones this environment's database references into its root. Idempotent, and
  # run by every deploy script, so each environment adopts its own files.
  desc "Copy this environment's pre-split Active Storage files into its own root"
  task adopt_legacy: :environment do
    result = LegacyStorageAdoption.new.call
    puts "Copied #{result.copied}, already in place #{result.present}, " \
         "missing #{result.missing.size}"
    result.missing.each { |key| puts "  missing: #{key}" }
  end
end
