# frozen_string_literal: true

module Itp
  # Read-only Support summary inside the IT Portal shell (#43 spike 1).
  # Does not call Service Desk APIs or SQL; outbound deep-link only.
  class SupportController < BaseController
    before_action -> { require_app_feature('itp', 'support', fallback: itp_root_path) }

    # Default matches Production::Links "GSA Service Desk" host plus the
    # live Support tickets route. Override per machine with ITPORTAL_SUPPORT_URL
    # in .env.local (never LockBox secrets — this is a public intranet URL).
    DEFAULT_SUPPORT_URL = 'https://gsa-itportal/tickets'

    def index
      @support_url = ENV.fetch('ITPORTAL_SUPPORT_URL', DEFAULT_SUPPORT_URL)
    end
  end
end
