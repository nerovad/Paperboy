# frozen_string_literal: true

module DigitalAssetManagement
  # Named, ordered groupings of assets.
  class CollectionsController < BaseController
    before_action -> { require_app_feature('digital_asset_management', 'collections', fallback: digital_asset_management_root_path) }
    before_action :set_collection, only: %i[show edit update destroy remove_asset]

    def index
      @collections = Dam::Collection.alphabetical
      @favorite_ids = Dam::Favorite.ids_for(employee_id: dam_employee_id, type: 'Dam::Collection')
      @counts = Dam::CollectionAsset.group(:collection_id).count
    end

    def show
      record_recent_view(@collection)
      @assets = @collection.ordered_assets.includes(:storage_location).with_attached_file
      @favorite_ids = Dam::Favorite.ids_for(employee_id: dam_employee_id, type: 'Dam::Asset')
    end

    def new
      @collection = Dam::Collection.new(parent_id: params[:parent_id])
      @parents = Dam::Collection.alphabetical
    end

    def create
      @collection = Dam::Collection.new(collection_params)
      @collection.created_by_id = dam_employee_id
      @collection.created_by_name = dam_actor_name

      if @collection.save
        redirect_to digital_asset_management_collection_path(@collection), notice: 'Collection created.'
      else
        @parents = Dam::Collection.alphabetical
        render :new, status: :unprocessable_entity
      end
    end

    def edit
      # A collection cannot be its own parent, and offering itself in the list
      # is the easiest way for someone to create a cycle by accident.
      @parents = Dam::Collection.alphabetical.where.not(id: @collection.id)
    end

    def update
      if @collection.update(collection_params)
        redirect_to digital_asset_management_collection_path(@collection), notice: 'Collection updated.'
      else
        @parents = Dam::Collection.alphabetical.where.not(id: @collection.id)
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @collection.destroy
      redirect_to digital_asset_management_collections_path, notice: 'Collection deleted.'
    end

    # Adding an asset that is already in the collection is a no-op rather than
    # an error — this is reached from a grid where the state may be stale.
    def add_asset
      collection = Dam::Collection.find(params[:collection_id])
      asset = Dam::Asset.find(params[:asset_id])
      Dam::CollectionAsset.create_or_find_by!(collection: collection, asset: asset)
      redirect_back fallback_location: digital_asset_management_collection_path(collection),
                    notice: "Added #{asset.title} to #{collection.name}."
    end

    def remove_asset
      @collection.collection_assets.where(asset_id: params[:asset_id]).destroy_all
      redirect_back fallback_location: digital_asset_management_collection_path(@collection),
                    notice: 'Removed from collection.'
    end

    private

    def set_collection
      @collection = Dam::Collection.find(params[:id])
    end

    def collection_params
      params.require(:collection).permit(:name, :description, :parent_id)
    end
  end
end
