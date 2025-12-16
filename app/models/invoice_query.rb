class InvoiceQuery
  # Executes County stored procedure to fetch invoice data
  def self.fetch(fiscal_year:, agency:, account:)
    sql = <<-SQL
      EXEC dbo.Export_TC60_Invoice
        @FiscalYear = #{fiscal_year},
        @Agency     = '#{agency}',
        @Account    = '#{account}'
    SQL

    # TODO:  Below is the real quesry.
    # sql = <<-SQL
    #   EXEC dbo.Export_TC60_To_Billing_File
    #     @start_date = #{start_date},
    #     @end_date   = #{end_date},
    #     @type       = #{type},
    #     @digits     = '#{digits}',
    #     @encumbered = '#{encumbered}'
    # SQL

    result = ActiveRecord::Base.connection.exec_query(sql)
    result.to_a # return array of hashes
  end
end
