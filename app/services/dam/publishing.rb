# frozen_string_literal: true

module Dam
  # Sending a finished asset somewhere the public can see it.
  #
  # Every provider is an adapter class under this module, registered below.
  # The rest of the app — the target form, the picker on an asset, the runner
  # — asks the adapter what it takes and what it needs rather than branching
  # on the provider name, so a sixth service is a new class and one line here.
  module Publishing
    class Error < StandardError; end

    # The installation is missing something: a client id in .env, a token, a
    # public address. Worth saying plainly, because none of it is fixable by
    # retrying.
    class NotConfigured < Error; end

    # The far end said no. Carries the HTTP status so the publication can
    # record it alongside the message.
    class DeliveryFailed < Error
      attr_reader :response_code

      def initialize(message, response_code: nil)
        super(message)
        @response_code = response_code
      end
    end

    ADAPTERS = {
      'youtube' => 'Dam::Publishing::Youtube',
      'vimeo' => 'Dam::Publishing::Vimeo',
      'instagram' => 'Dam::Publishing::Instagram',
      'facebook' => 'Dam::Publishing::Facebook',
      'tiktok' => 'Dam::Publishing::Tiktok',
      'http' => 'Dam::Publishing::HttpEndpoint'
    }.freeze

    class << self
      def provider_keys = ADAPTERS.keys

      def adapter(provider)
        name = ADAPTERS[provider.to_s]
        raise Error, "No publish adapter for #{provider.inspect}" if name.blank?

        name.constantize
      end

      # [label, key] pairs for the target form's provider select.
      def options_for_select
        provider_keys.map { |key| [adapter(key).label, key] }
      end

      # Where a provider that fetches rather than receives will come back to.
      # Its own setting because the app is reached from inside the county by a
      # name the outside world cannot resolve.
      def public_base_url
        ENV.fetch('PAPERBOY_PUBLIC_BASE_URL', nil).presence&.chomp('/')
      end
    end
  end
end
