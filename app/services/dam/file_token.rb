# frozen_string_literal: true

module Dam
  # Signed, short-lived links to an asset's bytes for the person a page was
  # drawn for.
  #
  # Stock Active Storage URLs (/rails/active_storage/blobs/...) never expire
  # and ask nobody who is fetching them, so an asset the access rules hide
  # would stay one pasted link away. Instead the page is drawn with a token
  # naming the asset, which copy, how it is to be served and who it was issued
  # to; DigitalAssetManagement::FilesController honours it only for that
  # signed-in person and only for LIFETIME. The access check happened when
  # the page was drawn, so a grid of two hundred thumbnails does not re-run
  # the rules two hundred times.
  module FileToken
    VARIANTS = %w[file proxy thumbnail].freeze
    DISPOSITIONS = %w[inline attachment].freeze

    # Long enough for a page left open over lunch, short enough that a copied
    # link is not a standing way in.
    LIFETIME = 4.hours

    PURPOSE = :dam_file

    module_function

    def generate(asset, variant, employee_id:, disposition: 'inline')
      verifier.generate({ 'asset' => asset.id, 'variant' => variant.to_s, 'employee' => employee_id.to_s,
                          'disposition' => disposition.to_s },
                        expires_in: LIFETIME, purpose: PURPOSE)
    end

    # The claims, or nil for anything forged, expired or naming a copy or a
    # disposition this does not serve.
    def read(token)
      claims = verifier.verified(token.to_s, purpose: PURPOSE)
      return nil unless claims.is_a?(Hash)
      return nil unless VARIANTS.include?(claims['variant']) && DISPOSITIONS.include?(claims['disposition'])

      claims
    rescue ActiveSupport::MessageVerifier::InvalidSignature
      nil
    end

    def verifier = Rails.application.message_verifier(PURPOSE)
  end
end
