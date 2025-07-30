class BillingToolsController < ApplicationController
  def new
    @sDate = Date.today.beginning_of_month
    @eDate = Date.today.end_of_month
  end

  def move_to_production
    run_stored_proc("Move_Staging_To_Production", date_params)
    redirect_to new_billing_tool_path, notice: "Moved to production successfully"
  end

  def run_monthly_billing
    run_stored_proc("MonthlyBilling", date_params)
    redirect_to new_billing_tool_path, notice: "Monthly billing complete"
  end

  def backup_staging
    run_stored_proc("Backup_Staging")
    redirect_to new_billing_tool_path, notice: "Staging backed up"
  end

  def backup_production
    run_stored_proc("Backup_Production")
    redirect_to new_billing_tool_path, notice: "Production backed up"
  end

  private

  def date_params
    {
      sDate: params[:s_date].presence || '2023-07-01',
      eDate: params[:e_date].presence || '2062-12-31'
    }
  end

  def run_stored_proc(proc_name, args = {})
    placeholders = args.keys.map { |k| "@#{k} = ?" }.join(", ")
    sql = "EXEC [GSABSS].[dbo].[#{proc_name}] #{placeholders}"
    values = args.values

    ActiveRecord::Base.connection.exec_query(
      ActiveRecord::Base.send(:sanitize_sql_array, [sql, *values])
    )
  end
end
