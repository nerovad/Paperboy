# frozen_string_literal: true

module Aim
  # AIM's paged lists (#101).
  module ListHelper
    # What Rows offers under a list; 0 is All.
    PAGE_SIZES = [10, 25, 50, 100, Pfa::Grid::Table::PAGE_ROWS, 0].freeze

    # The data a list page's aim-queue-filter element carries to page its rows
    # as Records and DataRunner do: Pfa::Grid::Table::PAGE_ROWS a page.
    def aim_paged_list_data(**extra)
      { controller: 'aim-queue-filter', aim_queue_filter_page_size_value: Pfa::Grid::Table::PAGE_ROWS }.merge(extra)
    end
  end
end
