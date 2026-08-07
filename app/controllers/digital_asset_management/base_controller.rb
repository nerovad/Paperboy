# frozen_string_literal: true

module DigitalAssetManagement
  # Base controller for the Digital Asset Management app. Every Digital Asset Management controller should
  # inherit from this so the ACL gate below is applied consistently.
  class BaseController < ApplicationController
    before_action :require_app_access
    before_action :load_search_facets

    helper_method :dam_employee_id, :dam_favorite?

    private

    # The sidebar app switcher only *hides* apps the user cannot reach, so
    # this is the real gate: without it Digital Asset Management would stay reachable by
    # typing the URL. Access is granted per group or org level under
    # ACL > Applications; system admins bypass it.
    #
    # The signed-in check matters: a global (all-org-nil) application grant
    # applies to everyone, so the grant alone would let a signed-out visitor
    # through.
    def require_app_access
      return if current_user.present? && helpers.can_access_app?('digital_asset_management')

      redirect_to root_path, alert: 'You do not have access to Digital Asset Management.'
    end

    # The sidebar — and so the Advanced Search modal inside it — renders on
    # every DAM page, and the modal's selects are built from live data rather
    # than hardcoded lists. All five are small reference tables.
    def load_search_facets
      # Built from the live request so the modal reopens showing whatever
      # filters produced the page you are looking at.
      @dam_search = Dam::AssetSearch.new(params)
      @dam_media_types = Dam::Asset::MEDIA_TYPES
      @dam_formats = Dam::Asset.formats_in_use
      @dam_uploaders = Dam::Asset.uploaders
      @dam_storage_locations = Dam::StorageLocation.active.ordered
      @dam_metadata_fields = Dam::MetadataField.active.ordered
    end

    def dam_employee_id
      current_user&.employee_id.to_s
    end

    # Actor names are snapshotted onto DAM rows rather than joined at render
    # time, so an asset stays attributable after the uploader leaves.
    def dam_actor_name
      return nil unless current_user

      "#{current_user.first_name} #{current_user.last_name}".strip.presence
    end

    def dam_favorite?(subject)
      Dam::Favorite.favorited?(employee_id: dam_employee_id, subject: subject)
    end

    # Stamps the Dashboard's "recent" list. A browsing side effect, so it never
    # blocks the page it is recording.
    def record_recent_view(subject)
      Dam::RecentView.record!(employee_id: dam_employee_id, subject: subject)
    end
  end
end
