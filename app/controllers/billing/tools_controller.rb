# frozen_string_literal: true

module Billing
  # The stored-procedure actions behind the Billing sidebar's tool buttons.
  # These used to live on a top-level BillingToolsController with its own
  # /billing_tools page; the page is gone and the buttons moved into the
  # sidebar, but the actions and the procs they call are unchanged.
  #
  # Access is deliberately narrower than the rest of the Billing app: the app
  # gate comes from BaseController, and require_system_admin keeps these
  # destructive procs system-admin-only, exactly as they were before the move.
  class ToolsController < BaseController
    before_action :require_system_admin

    def move_to_production
      run_stored_proc('Move_Staging_To_Production', date_params)
      redirect_to billing_root_path, notice: 'Moved to production successfully'
    end

    def monthly_billing
      load_fiscal_periods
      select_current_period
    end

    def run_monthly_billing
      @start_date = params[:s_date]
      @end_date = params[:e_date]

      unless valid_date_range?
        load_fiscal_periods
        flash.now[:alert] = 'Start date must be on or before end date.'
        render :monthly_billing, status: :unprocessable_entity
        return
      end

      run_stored_proc('MonthlyBilling', date_params)
      redirect_to billing_root_path, notice: 'Monthly billing complete'
    end

    def backup_staging
      run_stored_proc('Backup_Staging')
      redirect_to billing_root_path, notice: 'Staging backed up'
    end

    def backup_production
      run_stored_proc('Backup_Production')
      redirect_to billing_root_path, notice: 'Production backed up'
    end

    private

    def load_fiscal_periods
      sql = <<~SQL.squish
        DECLARE @fyear varchar(4) = GSABSS.dbo.fnGetFiscalYear(?);
        SELECT [Year] AS FYEAR, ApMon, sDate, eDate
        FROM GSABSS.dbo.GetFiscalData(@fyear, @fyear)
        ORDER BY sDate
      SQL
      sanitized_sql = ActiveRecord::Base.send(
        :sanitize_sql_array, [sql, Date.current.iso8601]
      )
      @fiscal_periods = BillingBase.connection.exec_query(sanitized_sql).map do |period|
        period.transform_keys(&:downcase)
      end
    end

    def select_current_period
      current_period = @fiscal_periods.find do |period|
        Date.current.between?(period['sdate'].to_date, period['edate'].to_date)
      end
      return unless current_period

      @start_date = current_period['sdate'].to_date.iso8601
      @end_date = current_period['edate'].to_date.iso8601
    end

    def valid_date_range?
      Date.iso8601(@start_date) <= Date.iso8601(@end_date)
    rescue Date::Error
      false
    end

    def date_params
      {
        sDate: params[:s_date].presence || '2023-07-01',
        eDate: params[:e_date].presence || '2062-12-31'
      }
    end

    def run_stored_proc(proc_name, args = {})
      placeholders = args.keys.map { |k| "@#{k} = ?" }.join(', ')
      sql = "EXEC [GSABSS].[dbo].[#{proc_name}] #{placeholders}"
      values = args.values

      BillingBase.connection.exec_query(
        ActiveRecord::Base.send(:sanitize_sql_array, [sql, *values])
      )
    end
  end
end
