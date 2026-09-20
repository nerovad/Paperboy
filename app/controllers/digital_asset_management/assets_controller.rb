# frozen_string_literal: true

module DigitalAssetManagement
  # The library itself: browse, search, ingest and edit assets.
  #
  # #index is the single search results page. The sidebar box and the Advanced
  # Search modal both land here — see Dam::AssetSearch for how one set of
  # params covers both.
  class AssetsController < BaseController
    include Pagy::Method

    # Only the results page is the "Search" grant. An individual asset is
    # reached from a collection or a share too, so gating #show on search
    # would break those for anyone who holds them without it.
    before_action -> { require_app_feature('digital_asset_management', 'search', fallback: digital_asset_management_root_path) }, only: :index
    before_action :set_asset, only: %i[show edit update destroy share original]
    before_action :load_upload_targets, only: %i[new create edit update]

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
      @asset = Dam::Asset.new(storage_location_id: dam_upload_target&.id)
    end

    # The full-resolution file of an asset the library references rather than
    # holds. Sent from the share it lives on, and only ever from inside the
    # folder its location scans — the path is on a row anyone who can edit an
    # asset could have written, so it is never trusted as a path to read.
    def original
      path = @asset.original_path
      refusal = unreadable_reason(path)
      return redirect_to digital_asset_management_asset_path(@asset), alert: refusal if refusal

      send_file path.to_s, filename: @asset.filename, type: @asset.content_type,
                           disposition: 'attachment'
    end

    def create
      @asset = Dam::Asset.new(asset_params.except(:file))
      # An ingest that names no location still has to land somewhere: the
      # uploader's own destination, or the library default. See the Storage
      # screen, where both are set.
      @asset.storage_location_id ||= dam_upload_target&.id
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
        Dam::Job.record!(job_type: 'ingest', actor: current_user, subject: @asset,
                         log: "Ingested #{@asset.filename} (#{@asset.display_size}) " \
                              "into #{@asset.storage_location&.label || 'no location'}")
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

    def unreadable_reason(path)
      return 'That file is not reachable from here.' if path.blank?
      return nil if @asset.storage_location&.holds_source?(path)

      'That file is outside the folder this location reads.'
    end

    def asset_params
      params.require(:asset).permit(:title, :description, :storage_location_id, :file)
    end

    def load_upload_targets
      @dam_upload_targets = Dam::StorageLocation.upload_options_for(@asset&.storage_location)
    end

    def stamp_uploader(asset)
      asset.uploaded_by_id = dam_employee_id
      asset.uploaded_by_name = dam_actor_name
    end

    def assign_metadata(asset)
      Dam::MetadataAssignment.apply(asset, params[:metadata])
    end
  end
end
