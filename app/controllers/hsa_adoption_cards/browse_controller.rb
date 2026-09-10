# frozen_string_literal: true

module HsaAdoptionCards
  # The Browse screen: the whole card index one sorted page at a time. GET
  # renders the page; POST returns one page of rows with the total count.
  class BrowseController < BaseController
    before_action { require_feature('browse') }

    def index
      @share_status = CardFile.status
    end

    def create
      render_rows { CardBrowse.call(json_params, app_user: app_user) }
    end
  end
end
