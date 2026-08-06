# frozen_string_literal: true

module Billing
  class BillingType < BillingBase
    self.table_name = 'GSABSS.dbo.TC60_Types'
    self.primary_key = 'TYPE'
    self.inheritance_column = nil

    alias_attribute :code, :TYPE
    alias_attribute :active, :ACTIVE
    alias_attribute :name, :NAME

    validates :active, inclusion: { in: [true, false] }
  end
end
