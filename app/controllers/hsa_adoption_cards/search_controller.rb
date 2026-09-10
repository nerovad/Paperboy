# frozen_string_literal: true

module HsaAdoptionCards
  # The Search screen: a single box that works out what it was given, plus
  # the specific fields beneath it. GET renders the page; POST takes the
  # page's JSON and returns the matching cards grouped by case.
  class SearchController < BaseController
    before_action { require_feature('search') }

    def index
      @share_status = CardFile.status
    end

    def create
      render_rows { CardSearch.call(json_params, app_user: app_user) }
    end
  end
end
