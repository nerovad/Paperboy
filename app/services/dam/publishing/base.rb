# frozen_string_literal: true

module Dam
  module Publishing
    # What every publish adapter is.
    #
    # The class methods describe the provider to the rest of the app — what it
    # takes, what it asks for on the target form, whether it signs in with
    # OAuth — so no screen has to know the difference between YouTube and a
    # webhook. The instance does one delivery and says where it landed.
    #
    # An adapter never touches the publication's status: it either returns a
    # Result or raises DeliveryFailed. Dam::Publishing::Runner owns the row.
    class Base
      Result = Struct.new(:external_id, :external_url, :response_code, keyword_init: true)

      class << self
        def label = name.demodulize.titleize

        # Media types of Dam::Asset this provider will take.
        def media_types = %w[video]

        def oauth? = true

        # Whether the provider fetches the file from a link instead of being
        # handed the bytes. Those need Paperboy to be reachable from outside.
        def needs_public_url? = false

        # :expiring or :permanent — whether a connection has to be renewed.
        def token_lifetime = :expiring

        # What the target form asks for besides a name, as
        # { label:, hint:, required: }. nil means the token says which account
        # it is and nothing more is needed.
        def account_prompt = nil

        # Visibility choices offered when publishing, as { stored => label }.
        def privacy_options = {}

        def default_privacy = privacy_options.keys.first
      end

      attr_reader :publication, :target, :asset

      def initialize(publication, http: Http.new, access_token: nil)
        @publication = publication
        @target = publication.publish_target
        @asset = publication.asset
        @http = http
        @access_token = access_token
      end

      def deliver = raise(NotImplementedError, "#{self.class} cannot deliver")

      private

      attr_reader :http, :access_token

      def log(line) = publication.append_log(line)

      def bearer(extra = {})
        { 'Authorization' => "Bearer #{access_token}", 'Accept' => 'application/json' }.merge(extra)
      end

      def privacy = publication.privacy.presence || target.default_privacy.presence || self.class.default_privacy

      def description = publication.description.to_s

      def filename = asset.filename.presence || "#{asset.title.parameterize}.#{asset.format.to_s.downcase.presence || 'bin'}"

      def content_type = asset.content_type.presence || 'application/octet-stream'

      # The original, as a readable path, for however long the block runs. A
      # referenced asset is read where it lies; a stored one is written out to
      # a temp file, the same way the derivative builder reads it.
      def with_source_file
        path = asset.referenced? ? asset.original_path : nil
        raise DeliveryFailed, 'The original file is not reachable from this server.' if asset.referenced? && path.nil?
        return yield(path.to_s, path.size) if path

        raise DeliveryFailed, 'This asset has no file attached.' unless asset.file.attached?

        asset.file.open { |file| yield(file.path, File.size(file.path)) }
      end

      # A link the far end can fetch the file from, live only while this
      # publish is. Providers that pull rather than receive — Instagram — have
      # no other way in, so a missing public address is a configuration error
      # worth naming rather than a timeout twenty minutes later.
      def public_file_url
        base = Publishing.public_base_url
        if base.blank?
          raise NotConfigured, "#{self.class.label} fetches the file over the internet, so PAPERBOY_PUBLIC_BASE_URL " \
                               'must name an address this server can be reached at from outside.'
        end

        "#{base}/dam/media/#{publication.ensure_public_token!}"
      end

      # Every adapter's error path: say which step failed, and what the far
      # end said about it.
      def expect!(response, step)
        return response if response.success?

        raise DeliveryFailed.new("#{self.class.label} refused the #{step}: #{response.error_message}",
                                 response_code: response.code)
      end

      def account_ref!
        prompt = self.class.account_prompt
        return target.account_ref if target.account_ref.present?

        raise NotConfigured, "#{target.label} needs its #{prompt[:label]} filled in before it can publish."
      end
    end
  end
end
