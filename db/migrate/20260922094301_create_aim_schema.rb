# frozen_string_literal: true

# AIM's tables live in their own SQL schema, aim, inside the Paperboy
# database, so they stay visibly apart from everything in dbo.
#
# Every AIM migration after this one writes schema-qualified table names and
# names its indexes explicitly: the default index name for "aim.invoices"
# comes out as index_aim.invoices_on_..., and SQL Server rejects the dot.
class CreateAimSchema < ActiveRecord::Migration[8.1]
  def up
    create_schema 'aim'
  end

  def down
    drop_schema 'aim'
  end
end
