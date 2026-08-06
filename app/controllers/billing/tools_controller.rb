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

    def backup_staging
      run_stored_proc('Backup_Staging')
      redirect_to billing_root_path, notice: 'Staging backed up'
    end

    def backup_production
      run_stored_proc('Backup_Production')
      redirect_to billing_root_path, notice: 'Production backed up'
    end

    private

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
