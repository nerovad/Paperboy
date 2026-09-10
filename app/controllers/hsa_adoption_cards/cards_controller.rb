# frozen_string_literal: true

module HsaAdoptionCards
  # Streams one scanned card to the in-page viewer. The path is the card's
  # stored Filepath; CardFile confines it to the scanned-cards share. The
  # file is served inline and read-only — a person who wants a copy saves it
  # from the viewer, and the source scan is never touched.
  #
  # Reaching a card at all already means holding Search or Browse, since
  # those are the only screens that hand out a path; either grant will do.
  class CardsController < BaseController
    before_action :require_search_or_browse

    def pdf
      file = CardFile.resolve(params[:path])
      send_file file, type: 'application/pdf', disposition: 'inline'
    rescue HsaAdoptionCards::Error => e
      render plain: e.message, status: :not_found
    end

    private

    def require_search_or_browse
      return if helpers.can_use_app_feature?('hsa_adoption_cards', 'search') ||
                helpers.can_use_app_feature?('hsa_adoption_cards', 'browse')

      redirect_to hsa_adoption_cards_root_path, alert: 'Access denied.'
    end
  end
end
