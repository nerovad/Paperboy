# frozen_string_literal: true

module Aim
  # AIM's paged lists (#101).
  module ListHelper
    # The data a list page's aim-queue-filter element carries to page its rows
    # as Records and DataRunner do: Pfa::Grid::Table::PAGE_ROWS a page.
    def aim_paged_list_data(**extra)
      { controller: 'aim-queue-filter', aim_queue_filter_page_size_value: Pfa::Grid::Table::PAGE_ROWS }.merge(extra)
    end
  end
end
