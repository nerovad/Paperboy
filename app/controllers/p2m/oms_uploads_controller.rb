# frozen_string_literal: true

module P2m
  class OmsUploadsController < ApplicationController
    MAX_DEADLOCK_RETRIES = 2

    include Pagy::Method
    include DateRange

    before_action -> { require_app_feature('p2m', 'oms_status', fallback: p2m_root_path) }
    before_action :set_dates

    def index
      validate_date_range!
      @pagy, @uploads = pagy(:offset, listed_uploads)
    rescue ArgumentError
      @uploads = OmsUpload.none
      render_invalid_date_range(:index)
    end

    def reconcile
      validate_date_range!
      count = with_deadlock_retry { OmsUploadLedger.new.reconcile_imported!(scope: selected_uploads) }
      redirect_to p2m_oms_status_path(oms_uploads: selected_dates),
                  notice: reconciliation_notice(count), status: :see_other
    rescue ArgumentError
      @uploads = OmsUpload.none
      render_invalid_date_range(:index)
    end

    private

    def date_range_param_key
      :oms_uploads
    end

    def selected_uploads
      OmsUpload.where.not(status: 'removed').where(mailer_date: @start_date..@end_date)
    end

    def listed_uploads
      selected_uploads.includes(:files, :findings).newest_first
    end

    def selected_dates
      { start_date: @start_date.iso8601, end_date: @end_date.iso8601 }
    end

    def reconciliation_notice(count)
      return 'No OMS uploads needed reconciliation.' if count.to_i.zero?

      "Reconciled #{count} #{'OMS upload'.pluralize(count)}."
    end

    def with_deadlock_retry
      attempts = 0
      begin
        yield
      rescue ActiveRecord::DeadlockVictim, ActiveRecord::Deadlocked
        attempts += 1
        raise if attempts > MAX_DEADLOCK_RETRIES

        sleep(0.05 * attempts)
        retry
      end
    end
  end
end
