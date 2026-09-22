# frozen_string_literal: true

module DigitalAssetManagement
  # The DAM landing slideshow, and behind it the real dashboard: what you
  # starred and what you last opened, assets and collections side by side.
  class DashboardController < BaseController
    SHELF_SIZE = 8

    # #home is the app's front door and must stay open to anyone who holds the
    # app itself; only the working dashboard behind it is a grant of its own.
    before_action only: :index do
      require_app_feature('digital_asset_management', 'dashboard', fallback: digital_asset_management_root_path)
    end

    # The app's front door — a slideshow, matching every other sub-app.
    def home; end

    def index
      @favorite_assets = favorites_of(Dam::Asset)
      @favorite_collections = favorites_of(Dam::Collection)
      @recent_assets = still_viewable(Dam::RecentView.subjects_for(employee_id: dam_employee_id, type: 'Dam::Asset',
                                                                   limit: SHELF_SIZE))
      @recent_collections = Dam::RecentView.subjects_for(employee_id: dam_employee_id, type: 'Dam::Collection',
                                                         limit: SHELF_SIZE)
      @open_jobs = Dam::Job.open.newest_first.limit(5)
      @library_count = dam_access.viewable(Dam::Asset.visible).count
    end

    private

    # Favourites are polymorphic rows, so the subjects are loaded in one query
    # per type and then put back in starred order.
    def favorites_of(model)
      favorites = Dam::Favorite.for_employee(dam_employee_id)
                               .where(favoritable_type: model.name)
                               .newest_first.limit(SHELF_SIZE)
      subjects = model.where(id: favorites.map(&:favoritable_id))
      subjects = dam_access.viewable(subjects) if model == Dam::Asset
      subjects = subjects.index_by(&:id)
      favorites.filter_map { |favorite| subjects[favorite.favoritable_id] }
    end

    # A star or a recent view outlives the access that allowed it: a rule
    # added since hides the asset, so the shelf drops it too.
    def still_viewable(assets)
      allowed = dam_access.viewable(Dam::Asset.where(id: assets.map(&:id))).pluck(:id).to_set
      assets.select { |asset| allowed.include?(asset.id) }
    end
  end
end
