#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative '../db/mssql_helpers'

DATABASE = 'GSA Scan'
PROCEDURE = 'OversizedUpdateProfileTypeAndBU'

def exec_sql(database, procedure)
  database_sql = MssqlHelpers.quote_ident(database)
  procedure_sql = MssqlHelpers.sql_qualified('dbo', procedure)

  "EXEC #{database_sql}.#{procedure_sql}"
end

MssqlHelpers.load_dotenv!

host = ENV['DATARUNNER_TARGET_HOST'].to_s
client = MssqlHelpers.connect!(host, database: DATABASE)

begin
  client.execute(exec_sql(DATABASE, PROCEDURE)).do
  puts "[OK] Executed [#{DATABASE}].dbo.#{PROCEDURE}"
ensure
  client.close
end
