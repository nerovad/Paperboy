# frozen_string_literal: true

# Generic form-submission -> Records-table row ingestion. Finds the Records
# table whose declared source form matches the submission (see
# Registry.registry_fed_by) and creates a row from its field mapping. This
# replaces bespoke per-form "create inventory record" code: adding a new
# form->table feed is a declaration on the model, not new plumbing here.
class RecordIngestion
  def self.ingest(form)
    table = RegistryTable.for_source(form.class)
    return nil unless table

    table.ingest(form)
  rescue StandardError => e
    Rails.logger.error("RecordIngestion failed for #{form.class} ##{form.try(:id)}: #{e.message}")
    nil
  end
end
