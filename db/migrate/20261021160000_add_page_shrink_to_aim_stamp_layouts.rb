# frozen_string_literal: true

# Making room for a stamp (#221): a layout may shrink each page's own
# contents to page_shrink percent (100: not at all) and move them to
# page_position (center, top, bottom, left, right). The stamp is never
# shrunk. A second run, or a run after a crash, adds only what is missing.
class AddPageShrinkToAimStampLayouts < ActiveRecord::Migration[8.1]
  def up
    add_column 'aim.stamp_layouts', :page_shrink, :integer unless column_exists?('aim.stamp_layouts', :page_shrink)
    return if column_exists?('aim.stamp_layouts', :page_position)

    add_column 'aim.stamp_layouts', :page_position, :string, limit: 10
  end

  def down
    remove_column 'aim.stamp_layouts', :page_position if column_exists?('aim.stamp_layouts', :page_position)
    remove_column 'aim.stamp_layouts', :page_shrink if column_exists?('aim.stamp_layouts', :page_shrink)
  end
end
