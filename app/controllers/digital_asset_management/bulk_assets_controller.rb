# frozen_string_literal: true

module DigitalAssetManagement
  # The action bar above the library: one thing done to every selected asset.
  #
  # Which assets is Dam::AssetSelection's call — ticked ids, or "select all",
  # which re-runs the search the results page was showing. Each action answers
  # with a redirect back to that page and a count of what it did.
  #
  # The grants are the same ones the single-asset versions ask for, plus
  # Search, since the only way here is the results page.
  class BulkAssetsController < BaseController
    include QueuesPublications

    # Every publish is an upload to somebody else's service, with no undo from
    # here. A selection this big is far more likely a slip of "select all" than
    # a plan, so it is refused and the search can be narrowed.
    MAX_PUBLISH = 100

    before_action -> { require_app_feature('digital_asset_management', 'search', fallback: digital_asset_management_root_path) }
    before_action -> { require_app_feature('digital_asset_management', 'publish', fallback: digital_asset_management_root_path) }, only: :publish
    before_action -> { require_app_feature('digital_asset_management', 'collections', fallback: digital_asset_management_root_path) }, only: :add_to_collection
    before_action :load_selection

    def publish
      target = Dam::PublishTarget.find(params[:publish_target_id])
      return back(alert: "Publish at most #{MAX_PUBLISH} assets at once; #{@selection.label} are selected.") if @selection.count > MAX_PUBLISH

      queued, refused = publish_each(target)
      back(**publish_outcome(target, queued, refused))
    end

    # One share per asset, so My Shares and each asset's own page list it just
    # as a share made from that asset would. All or none: a share that fails
    # validation fails for every asset alike.
    def share
      return back(alert: 'Enter at least one recipient.') if params[:recipients].blank?

      shares = @selection.scope.map { |asset| build_share(asset) }
      invalid = shares.find(&:invalid?)
      return back(alert: "Shares could not be created: #{invalid.errors.full_messages.to_sentence}") if invalid

      Dam::Share.transaction { shares.each(&:save!) }
      Dam::Job.record!(job_type: 'share', actor: current_user, subject: nil, count: shares.size,
                       label: @selection.label, log: "Shared with #{shares.first.recipient_list.join(', ')}")
      back(notice: "Shared #{@selection.label}.")
    end

    def metadata
      changes = metadata_changes
      return back(alert: 'Enter a value or tick Clear on at least one field.') if changes.empty?

      job = Dam::Job.enqueue!(job_type: 'metadata', actor: current_user, total_items: @selection.count,
                              label: @selection.label)
      job.append_log("Setting #{changes.map { |key, value| "#{key} = #{value.presence || '(cleared)'}" }.join(', ')}")
      job.save
      Dam::BulkMetadataJob.perform_later(job.id, @selection.ids, changes)
      back(notice: "Updating metadata on #{@selection.label}. Progress is on the Jobs screen.")
    end

    # Already-members are skipped rather than moved to the end, so adding a
    # selection that overlaps the collection keeps the order it already has.
    def add_to_collection
      collection = Dam::Collection.find(params[:collection_id])
      present = collection.collection_assets.pluck(:asset_id).to_set
      added = @selection.ids.reject { |id| present.include?(id) }
      added.each { |id| Dam::CollectionAsset.create_or_find_by!(collection: collection, asset_id: id) }
      back(notice: "Added #{helpers.pluralize(added.size, 'asset')} to #{collection.name}.")
    end

    # Archived, as a single asset is, never deleted.
    def archive
      count = @selection.scope.update_all(status: 'archived', updated_at: Time.current)
      back(notice: "Archived #{helpers.pluralize(count, 'asset')}.")
    end

    private

    def load_selection
      @selection = Dam::AssetSelection.from_params(params)
      back(alert: 'Select at least one asset first.') if @selection.empty?
    end

    def publish_each(target)
      queued = 0
      refused = Hash.new(0)
      @selection.scope.find_each do |asset|
        reason = target.refusal_reason(asset)
        next refused[reason] += 1 if reason

        publication = build_publication(asset, target)
        next refused[publication.errors.full_messages.to_sentence] += 1 unless publication.save

        queue_publication(publication)
        queued += 1
      end
      [queued, refused]
    end

    # Refusals are counted by reason — "12 skipped: does not take image files"
    # says what to do about it, where forty asset titles would not.
    def publish_outcome(target, queued, refused)
      skipped = refused.map { |reason, count| "#{count} skipped: #{reason}" }.join('; ')
      return { alert: "Nothing was published to #{target.label}. #{skipped}." } if queued.zero?

      message = "Publishing #{helpers.pluralize(queued, 'asset')} to #{target.label}."
      refused.any? ? { alert: "#{message} #{skipped}." } : { notice: message }
    end

    def build_share(asset)
      share = Dam::Share.new(
        subject: asset,
        permission: params[:permission].presence || 'view',
        message: params[:message],
        expires_at: params[:expires_at].presence,
        shared_by_id: dam_employee_id,
        shared_by_name: dam_actor_name
      )
      share.recipient_list = params[:recipients].to_s.split(/[\n,;]/)
      share
    end

    # A blank box means "leave this field alone" — the opposite of the
    # single-asset form, where the box shows the current value and blanking it
    # clears it. Here there is no one current value to show, so clearing is its
    # own tick box.
    def metadata_changes
      allowed = Dam::MetadataField.active.pluck(:key)
      values = params.fetch(:metadata, {}).permit(*allowed).to_h.transform_values { |value| value.to_s.strip }
      cleared = Array(params[:clear_metadata]).to_h { |key| [key.to_s, ''] }
      values.compact_blank.merge(cleared.slice(*allowed))
    end

    def back(**flash)
      redirect_back fallback_location: digital_asset_management_assets_path, **flash
    end
  end
end
