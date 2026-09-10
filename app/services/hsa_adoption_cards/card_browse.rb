# frozen_string_literal: true

module HsaAdoptionCards
  # dbo.HSA_Adopt_usp_BrowseCards: one sorted page of cards. Staff cannot read
  # the tables directly, so scrolling through them needs its own procedure,
  # and every page viewed is written to the search log like a search.
  class CardBrowse
    PROCEDURE = 'dbo.HSA_Adopt_usp_BrowseCards'

    MAPPING = {
      'cardType' => '@CardType', 'status' => '@GroupStatus', 'sortBy' => '@SortBy', 'sortDir' => '@SortDir',
      'page' => '@Page',         'pageSize' => '@PageSize',  'reason' => '@Reason'
    }.freeze

    def self.call(params, app_user:)
      new.call(params, app_user: app_user)
    end

    def call(params, app_user:)
      Procedure.new(PROCEDURE, MAPPING).call(params, app_user: app_user)
    end
  end
end
