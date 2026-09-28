# frozen_string_literal: true

module Aim
  # The Users & Queues screen.
  module AdminHelper
    # A column heading that sorts the list by it, keeping the view and filters.
    def aim_admin_sort_link(label, sort)
      text = @sort == sort ? "#{label} ▾" : label
      link_to text, aim_admin_path(@filters.merge(view: @view, sort: sort)), class: 'aim-sort-link'
    end
  end
end
