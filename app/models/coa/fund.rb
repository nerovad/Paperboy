module Coa
  class Fund < BaseRecord
    self.table_name = 'funds'
    self.primary_key = :fund_id
  end
end
