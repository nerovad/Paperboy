# frozen_string_literal: true

module DigitalAssetManagement
  # Where my uploads go.
  #
  # Its own controller, and the only ungated storage action, because it is the
  # only one that changes nothing for anyone else: two people ingesting on the
  # same afternoon are often filling different buckets — one loading a campaign
  # shoot, one draining a camera card into cold storage. Everything about the
  # locations themselves is StorageLocationsController.
  class UploadDestinationsController < BaseController
    def update
      # Resolved against the uploadable set rather than trusted, so a stale
      # form cannot pin someone to a location that has since been closed.
      chosen = Dam::StorageLocation.uploadable.find_by(id: params[:storage_location_id])
      UserSetting.for_employee(dam_employee_id).update(dam_storage_location_id: chosen&.id)
      destination = chosen ? "go to #{chosen.label}" : 'follow the library default'

      redirect_to digital_asset_management_storage_locations_path,
                  notice: "Your uploads will #{destination}."
    end
  end
end
