class Tc60Export
  # Wrapper around dbo.Export_TC60_To_Billing_File
  #
  # sDate, eDate: Date or "YYYY-MM-DD" strings
  # type:        "GDS" (or other 3-char type)
  # digits:      integer rounding precision
  # encumbered:  0 or 1
  #
  def self.call(sDate:, eDate:, type:, digits:, encumbered:)
    sql = <<-SQL
      EXEC dbo.Export_TC60_To_Billing_File
          @sDate = ?,
          @eDate = ?,
          @type = ?,
          @digits = ?,
          @encumbered = ?
    SQL

    sanitized = ActiveRecord::Base.send(
      :sanitize_sql_array,
      [sql, sDate, eDate, type, digits.to_i, encumbered.to_i]
    )

    result = BillingBase.connection.exec_query(sanitized)
    result.to_a # array of hashes
  end
end
