# frozen_string_literal: true

module DigitalAssetManagement
  # The star button, for both assets and collections.
  #
  # One toggle endpoint rather than a create/destroy pair, because the UI is a
  # single button whose state the caller may not know.
  class FavoritesController < BaseController
    # An allow-list, not a constantize: subject_type comes off a form field.
    SUBJECTS = { 'asset' => Dam::Asset, 'collection' => Dam::Collection }.freeze

    def toggle
      model = SUBJECTS[params[:subject_type].to_s]
      return redirect_back(fallback_location: digital_asset_management_dashboard_path, alert: 'Unknown item.') if model.nil?

      subject = model.find(params[:subject_id])
      starred = Dam::Favorite.toggle!(employee_id: dam_employee_id, subject: subject).present?

      redirect_back fallback_location: digital_asset_management_dashboard_path,
                    notice: starred ? 'Added to favorites.' : 'Removed from favorites.'
    end
  end
end
