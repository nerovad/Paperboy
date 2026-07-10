class InvoiceQuery
  # Executes County stored procedure to fetch invoice data
  def self.fetch(fiscal_year:, agency:, account:)
    sql = <<-SQL
      EXEC dbo.Export_TC60_Invoice
        @FiscalYear = ?,
        @Agency     = ?,
        @Account    = ?
    SQL

    sanitized = ActiveRecord::Base.send(
      :sanitize_sql_array,
      [sql, fiscal_year, agency, account]
    )

    result = BillingBase.connection.exec_query(sanitized)
    result.to_a # return array of hashes
  end
end
