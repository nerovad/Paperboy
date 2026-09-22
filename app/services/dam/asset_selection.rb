# frozen_string_literal: true

module Dam
  # The assets a bulk action on the library applies to.
  #
  # A selection arrives in one of two shapes. Ticking cards sends their ids:
  #
  #   asset_ids: ["12", "15", "31"]
  #
  # "Select all" sends the search instead, as the query string of the results
  # page it was pressed on:
  #
  #   select_all: "1", search: "q=board&media_type[]=video"
  #
  # The search is re-run here rather than the browser listing every id, so
  # "all" means every asset the search matches — not only the page of them
  # that was on screen — and a search is still defined by its URL alone. See
  # Dam::AssetSearch.
  #
  # Archived assets are never selected, whichever shape was sent: a bulk
  # action is always about the library as it is shown. Nor is anything the
  # person acting cannot see under the DAM access rules — a hand-built list of
  # ids is held to the same Dam::Access as the results page.
  class AssetSelection
    # Ids only ever come from one page of cards, so this is generous; it
    # exists to keep a hand-built request under SQL Server's 2,100 parameters.
    MAX_IDS = 1000

    def self.from_params(params, access: nil)
      new(asset_ids: params[:asset_ids], select_all: params[:select_all], search: params[:search], access: access)
    end

    def initialize(asset_ids: nil, select_all: nil, search: nil, access: nil)
      @asset_ids = Array(asset_ids).map(&:to_s).grep(/\A\d+\z/).uniq.first(MAX_IDS)
      @select_all = ActiveModel::Type::Boolean.new.cast(select_all)
      @search = search.to_s
      @access = access
    end

    def all? = @select_all

    def empty? = count.zero?

    def count
      @count ||= scope.count
    end

    # Plain assets with no ordering, so callers can batch over it. The search
    # arrives as a subquery rather than a list of ids, since "all" may be more
    # ids than SQL Server takes as parameters.
    def scope
      base = all? ? Dam::Asset.visible.where(id: search_ids) : Dam::Asset.visible.where(id: @asset_ids)
      @access ? @access.viewable(base) : base
    end

    # The part of the selection the person acting may do +capability+ to. The
    # rest is not an error: the controller reports how many were skipped.
    def permitted(capability)
      @access ? @access.permitted(scope, capability) : scope
    end

    def ids = scope.pluck(:id)

    def label = ActionController::Base.helpers.pluralize(count, 'asset')

    private

    # SQL Server refuses ORDER BY inside a subquery, and the preloads mean
    # nothing to one.
    def search_ids
      Dam::AssetSearch.new(Rack::Utils.parse_nested_query(@search), access: @access)
                      .results.unscope(:order, :includes, :preload, :eager_load).select(:id)
    end
  end
end
