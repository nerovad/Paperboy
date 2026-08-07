# frozen_string_literal: true

module DigitalAssetManagement
  # My Shares — the history of what the signed-in user has sent out.
  #
  # Scoped to shared_by_id rather than showing everything: this is a personal
  # history screen, not an audit console.
  class SharesController < BaseController
    include Pagy::Method

    before_action :set_share, only: %i[show revoke destroy]

    def index
      @state_filter = params[:state].to_s
      scope = Dam::Share.by_employee(dam_employee_id).in_state(@state_filter).newest_first
      scope = scope.where(subject_type: subject_class) if subject_class
      @pagy, @shares = pagy(:offset, scope)
      @counts = Dam::Share.by_employee(dam_employee_id).group(:subject_type).count
    end

    def show; end

    def revoke
      @share.revoke!
      redirect_to digital_asset_management_shares_path, notice: 'Share revoked.'
    end

    # Kept out of the list without erasing that it happened, since a revoked
    # share is still a thing that was sent.
    def destroy
      @share.revoke! unless @share.revoked?
      redirect_to digital_asset_management_shares_path, notice: 'Share revoked.'
    end

    private

    def set_share
      @share = Dam::Share.by_employee(dam_employee_id).find(params[:id])
    end

    def subject_class
      { 'asset' => 'Dam::Asset', 'collection' => 'Dam::Collection' }[params[:subject_type].to_s]
    end
  end
end
