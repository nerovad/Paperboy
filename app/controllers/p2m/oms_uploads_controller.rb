# frozen_string_literal: true

module P2m
  class OmsUploadsController < ApplicationController
    include Pagy::Method
    include DateRange

    before_action -> { require_app_feature('p2m', 'oms_status', fallback: p2m_root_path) }
    before_action :set_dates

    def index
      validate_date_range!
      OmsUploadLedger.new.reconcile_imported!
      scope = OmsUpload.includes(:files, :findings)
                       .where(mailer_date: @start_date..@end_date)
                       .newest_first
      @pagy, @uploads = pagy(:offset, scope)
    rescue ArgumentError
      @uploads = OmsUpload.none
      render_invalid_date_range(:index)
    end

    private

    def date_range_param_key
      :oms_uploads
    end
  end
end
