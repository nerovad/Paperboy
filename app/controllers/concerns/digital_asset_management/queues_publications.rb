# frozen_string_literal: true

module DigitalAssetManagement
  # Building and queueing a publication, shared by the Publish panel on one
  # asset and the bulk Publish on the library, so both leave the same receipt:
  # a queued Dam::Publication, a Jobs feed entry, and a Dam::PublishJob.
  module QueuesPublications
    extend ActiveSupport::Concern

    private

    # Title and description fall back to the asset's own, which is what a bulk
    # publish relies on — forty videos cannot share one typed title.
    def build_publication(asset, target, title: nil, description: nil)
      publication = Dam::Publication.new(
        asset: asset, publish_target: target, status: 'queued',
        title: title.presence || asset.title,
        description: description.presence || asset.description,
        privacy: params[:privacy].presence || target.default_privacy.presence || target.adapter_class.default_privacy,
        requested_by_id: dam_employee_id, requested_by_name: dam_actor_name
      )
      publication.tag_list = params[:tags].to_s.split(',')
      publication
    end

    # Every piece of DAM work shows up in the Jobs feed whether or not anyone
    # was watching the screen that started it.
    def queue_publication(publication)
      job = Dam::Job.enqueue!(job_type: 'publish', actor: current_user, subject: publication.asset, total_items: 1)
      job.append_log("Queued for #{publication.target_label}")
      job.save
      publication.update_columns(job_id: job.id, updated_at: Time.current)
      Dam::PublishJob.perform_later(publication.id)
    end
  end
end
