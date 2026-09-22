# frozen_string_literal: true

module DigitalAssetManagement
  # Storage: where the library's bytes live, and where new ones land.
  #
  # Two audiences share the screen. Anyone can see what is stored where, and
  # set their own upload destination — that one is UploadDestinationsController,
  # because it changes nothing for anybody else. Everything here does: adding,
  # retiring or draining a location changes the library, so it is gated on
  # system admin rather than merely hidden from the page.
  class StorageLocationsController < BaseController
    before_action -> { require_app_feature('digital_asset_management', 'storage', fallback: digital_asset_management_root_path) }
    before_action :set_location,
                  only: %i[show edit update destroy make_default toggle move_assets retry_failures
                           rebuild_derivatives]
    before_action :require_storage_admin, except: %i[index show]

    def index
      @locations = Dam::StorageLocation.ordered
      @asset_counts = Dam::StorageLocation.asset_counts
      @used_bytes = Dam::StorageLocation.used_bytes_by_location
      @unplaced_count = @asset_counts[nil].to_i

      @upload_targets = Dam::StorageLocation.uploadable.ordered
      @library_default = Dam::StorageLocation.library_default
      @my_choice_id = UserSetting.dam_storage_location_id_for(dam_employee_id)
      @my_target = dam_upload_target
    end

    def retry_failures
      forgotten = Dam::LocationDiagnostics.new(@location).forget_ingest_failures!
      redirect_to digital_asset_management_storage_location_path(@location),
                  notice: "#{forgotten} #{'file'.pluralize(forgotten)} will be tried again on the next scan."
    end

    def rebuild_derivatives
      queued = Dam::LocationDiagnostics.new(@location).rebuild_previews!

      redirect_to digital_asset_management_storage_location_path(@location),
                  notice: "Queued #{queued} #{'preview'.pluralize(queued)}. " \
                          'They appear as the jobs run.'
    end

    def show
      @diagnostics = Dam::LocationDiagnostics.new(@location)
      @asset_count = @location.asset_count
      @used_bytes = @location.used_bytes
      @by_media_type = @location.assets.group(:media_type).count
      @recent_assets = dam_access.viewable(@location.assets).newest_first.limit(8)

      # Moving into a read-only archive is a legitimate destination — that is
      # what an archive is for — so targets only have to be active.
      @move_targets = Dam::StorageLocation.active.ordered.where.not(id: @location.id)
      @jobs = Dam::Job.where(subject: @location).newest_first.limit(10)
    end

    def new
      @location = Dam::StorageLocation.new(kind: 'disk', active: true)
    end

    def create
      @location = Dam::StorageLocation.new(location_params)

      if @location.save
        redirect_to digital_asset_management_storage_location_path(@location),
                    notice: "#{@location.label} added."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit; end

    def update
      if @location.update(location_params)
        redirect_to digital_asset_management_storage_location_path(@location),
                    notice: "#{@location.label} updated."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    # Blocked while assets still point here — see the model's before_destroy.
    def destroy
      if @location.destroy
        redirect_to digital_asset_management_storage_locations_path, notice: "#{@location.label} removed."
      else
        redirect_to digital_asset_management_storage_location_path(@location),
                    alert: @location.errors.full_messages.to_sentence
      end
    end

    def make_default
      unless @location.accepts_uploads?
        return redirect_back fallback_location: digital_asset_management_storage_locations_path,
                             alert: "#{@location.label} is #{@location.refusal_reason}, " \
                                    'so it cannot be the default upload destination.'
      end

      @location.update(default_for_uploads: true)
      redirect_back fallback_location: digital_asset_management_storage_locations_path,
                    notice: "Uploads now default to #{@location.label}."
    end

    def toggle
      @location.update(active: !@location.active?)
      redirect_back fallback_location: digital_asset_management_storage_locations_path,
                    notice: "#{@location.label} #{@location.active? ? 'enabled' : 'disabled'}."
    end

    # Re-points every asset here at another location, so a place can be
    # drained before it is retired.
    #
    # This moves the catalogue, not the bytes: the file itself stays on
    # whatever Active Storage service holds it until the storage runner acts
    # on the job this raises. Recording the intent is the point — it is what
    # the runner works from, and what the Jobs feed shows afterwards.
    def move_assets
      target = Dam::StorageLocation.active.find_by(id: params[:target_id])
      if target.blank? || target == @location
        return redirect_to digital_asset_management_storage_location_path(@location),
                           alert: 'Choose another location to move these assets to.'
      end

      moved = @location.repoint_assets_to(target, actor: current_user)

      redirect_to digital_asset_management_storage_location_path(@location),
                  notice: "#{moved} #{'asset'.pluralize(moved)} moved to #{target.label}."
    end

    private

    def set_location
      @location = Dam::StorageLocation.find(params[:id])
    end

    def location_params
      params.require(:storage_location)
            .permit(:key, :label, :kind, :root, :description, :quota_gb,
                    :active, :read_only, :default_for_uploads, :position,
                    :watch_path, :ingest_mode, :accepted_formats, :ignore_patterns)
    end

    def require_storage_admin
      return if helpers.system_admin?

      redirect_to digital_asset_management_storage_locations_path,
                  alert: 'Only system administrators can change storage locations.'
    end
  end
end
