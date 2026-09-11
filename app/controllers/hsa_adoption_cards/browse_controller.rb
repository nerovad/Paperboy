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

    # The cards linked to one browse row: its whole case group. The search
    # procedure returns a direct hit plus the rest of its case, so a search
    # keyed on the row's own identifiers, narrowed to its group, is exactly
    # that set. Lives here rather than on the Search screen so that holding
    # Browse alone is enough to use it.
    def linked
      render_rows { LinkedCards.call(json_params, app_user: app_user) }
    end
  end
end
