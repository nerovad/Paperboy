# frozen_string_literal: true

module Dam
  # Writes one set of metadata changes onto many assets, away from the request
  # that asked — "select all" can mean thousands of saves.
  #
  # +changes+ is { field_key => value }, where an empty string clears the field.
  # It is handed to Dam::MetadataAssignment unchanged, so a bulk edit follows
  # exactly the rules the single-asset form does: unknown keys are dropped and
  # a cleared field loses its row.
  #
  # One asset that will not save is logged and skipped rather than failing the
  # rest; the job ends 'failed' if any did, so the Jobs feed says so.
  class BulkMetadataJob < ApplicationJob
    queue_as :default

    # Keeps each lookup well under SQL Server's 2,100 parameters.
    SLICE = 500

    discard_on ActiveRecord::RecordNotFound

    def perform(job_id, asset_ids, changes)
      job = Dam::Job.find(job_id)
      return unless job.status == 'queued'

      job.update!(status: 'running', started_at: Time.current)
      failures = asset_ids.each_slice(SLICE).sum { |slice| apply_to(job, slice, changes) }
      finish(job, failures)
    end

    private

    def apply_to(job, ids, changes)
      failures = 0
      Dam::Asset.where(id: ids).includes(:metadata_values).find_each do |asset|
        Dam::MetadataAssignment.apply(asset, changes)
        next if asset.save

        failures += 1
        job.append_log("#{asset.title}: #{asset.errors.full_messages.to_sentence}")
      end
      job.update!(processed_items: job.processed_items.to_i + ids.size, log: job.log)
      failures
    end

    def finish(job, failures)
      job.append_log("Updated #{job.total_items - failures} of #{job.total_items}")
      job.update!(status: failures.zero? ? 'succeeded' : 'failed', finished_at: Time.current,
                  error_message: failures.zero? ? nil : "#{failures} asset(s) could not be saved", log: job.log)
    end
  end
end
