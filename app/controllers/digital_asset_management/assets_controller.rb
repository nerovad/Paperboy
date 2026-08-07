# frozen_string_literal: true

module DigitalAssetManagement
  # The library itself: browse, search, ingest and edit assets.
  #
  # #index is the single search results page. The sidebar box and the Advanced
  # Search modal both land here — see Dam::AssetSearch for how one set of
  # params covers both.
  class AssetsController < BaseController
    include Pagy::Method

    before_action :set_asset, only: %i[show edit update destroy share]

    def index
      @pagy, @assets = pagy(:offset, @dam_search.results)
      @favorite_ids = Dam::Favorite.ids_for(employee_id: dam_employee_id, type: 'Dam::Asset')
      @collections = Dam::Collection.alphabetical
    end

    def show
      record_recent_view(@asset)
      @collections = Dam::Collection.alphabetical
      @jobs = Dam::Job.where(subject: @asset).newest_first.limit(10)
      @shares = Dam::Share.where(subject: @asset).newest_first.limit(10)
    end

    def new
      @asset = Dam::Asset.new
    end

    def create
      @asset = Dam::Asset.new(asset_params.except(:file))
      upload = asset_params[:file]

      if upload.blank?
        @asset.errors.add(:file, 'must be chosen')
        return render :new, status: :unprocessable_entity
      end

      @asset.apply_file_facts!(upload)
      @asset.file.attach(upload)
      stamp_uploader(@asset)
      assign_metadata(@asset)

      if @asset.save
        # Ingest is a job even though this one runs inline, so the Jobs feed is
        # a complete record of how everything got into the library.
        log_ingest(@asset)
        redirect_to digital_asset_management_asset_path(@asset), notice: 'Asset ingested.'
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit; end

    def update
      @asset.assign_attributes(asset_params.except(:file))
      assign_metadata(@asset)

      if @asset.save
        redirect_to digital_asset_management_asset_path(@asset), notice: 'Asset updated.'
      else
        render :edit, status: :unprocessable_entity
      end
    end

    # Archived rather than deleted: a DAM's whole job is not losing the master,
    # and collections, jobs and shares all point at this row.
    def destroy
      @asset.update(status: 'archived')
      redirect_to digital_asset_management_assets_path, notice: 'Asset archived.'
    end

    def share
      share = Dam::Share.new(
        subject: @asset,
        permission: params[:permission].presence || 'view',
        message: params[:message],
        expires_at: params[:expires_at].presence,
        shared_by_id: dam_employee_id,
        shared_by_name: dam_actor_name
      )
      share.recipient_list = params[:recipients].to_s.split(/[\n,;]/)

      if share.save
        Dam::Job.enqueue!(job_type: 'share', actor: current_user, subject: @asset, total_items: 1)
        redirect_to digital_asset_management_asset_path(@asset), notice: 'Share created.'
      else
        redirect_to digital_asset_management_asset_path(@asset),
                    alert: "Share could not be created: #{share.errors.full_messages.to_sentence}"
      end
    end

    private

    def set_asset
      @asset = Dam::Asset.find(params[:id])
    end

    def asset_params
      params.require(:asset).permit(:title, :description, :storage_location_id, :file)
    end

    def stamp_uploader(asset)
      asset.uploaded_by_id = dam_employee_id
      asset.uploaded_by_name = dam_actor_name
    end

    # Metadata arrives as { field_key => value }. A blank value clears the row
    # rather than storing an empty string, so "is blank" filters stay honest.
    def assign_metadata(asset)
      submitted = params[:metadata]
      return if submitted.blank?

      allowed = Dam::MetadataField.active.pluck(:key)
      submitted.to_unsafe_h.slice(*allowed).each do |key, value|
        row = asset.metadata_values.find { |candidate| candidate.field_key == key }
        if value.to_s.strip.blank?
          row&.mark_for_destruction
        elsif row
          row.value = value.to_s.strip
        else
          asset.metadata_values.build(field_key: key, value: value.to_s.strip)
        end
      end
    end

    def log_ingest(asset)
      job = Dam::Job.enqueue!(job_type: 'ingest', actor: current_user, subject: asset, total_items: 1)
      job.append_log("Ingested #{asset.filename} (#{asset.display_size})")
      job.update(status: 'succeeded', processed_items: 1, started_at: Time.current, finished_at: Time.current,
                 log: job.log)
    end
  end
end
