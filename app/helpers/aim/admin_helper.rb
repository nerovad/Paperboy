# frozen_string_literal: true

module Aim
  # The Users & Queues screen, and the sortable lists AIM draws.
  module AdminHelper
    # A column heading that sorts the current list by +sort+, keeping +keep+
    # (the page's view and filters), marked ▾ when it is the sort in force.
    # AIM's lists sort one way on a `sort` param, so this is simpler than
    # TableColumnsHelper#sortable_column_header, which pages My Work's
    # customisable columns both ways.
    def aim_sort_link(label, sort, keep = {})
      text = @sort == sort ? "#{label} ▾" : label
      link_to text, url_for(keep.to_h.symbolize_keys.merge(sort: sort, only_path: true)), class: 'aim-sort-link'
    end
  end
end
