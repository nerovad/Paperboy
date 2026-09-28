# frozen_string_literal: true

# An upload on the Lookups screen is previewed first and applied from the
# same row (item b.3), so the file's content and the choices made are kept
# on it.
class AddPreviewToAimCodingImports < ActiveRecord::Migration[8.1]
  def change
    add_column 'aim.coding_imports', :status, :string, limit: 20, null: false, default: 'applied'
    add_column 'aim.coding_imports', :file_content, :text
    add_column 'aim.coding_imports', :default_unit, :string, limit: 10
  end
end
