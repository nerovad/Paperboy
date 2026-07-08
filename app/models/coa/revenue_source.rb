module Coa
  class RevenueSource < BaseRecord
    self.table_name = "revenue_sources"
    self.primary_key = :revenue_source_id
  end
end
