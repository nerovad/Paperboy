# frozen_string_literal: true

module Dam
  # Somewhere the library can send a finished asset.
  #
  # A target is one account on one service — this channel, that page — rather
  # than the service itself, because an organisation has more than one: a
  # department's YouTube channel and the county's are two places, and which of
  # them a video went to is the whole point of the record.
  #
  # What a provider can take, how it authenticates and how the bytes get there
  # is the adapter's business (Dam::Publishing); this row holds only the
  # account, the tokens and whether anyone may still publish to it. That is
  # what lets 'http' — a URL of our own, with headers typed into the form — be
  # a target like any other rather than a special case.
  #
  # Tokens are encrypted at rest. The client id and secret they were issued
  # against are not here at all: they are per host, in .env, because they
  # identify the installation rather than the account.
  class PublishTarget < ApplicationRecord
    HTTP_METHODS = %w[POST PUT].freeze

    BODY_STYLES = {
      'multipart' => 'Send the file (multipart form)',
      'json' => 'Send a JSON description, with a link to the file'
    }.freeze

    encrypts :oauth_access_token
    encrypts :oauth_refresh_token

    has_many :publications, class_name: 'Dam::Publication', dependent: :restrict_with_error,
                            foreign_key: :publish_target_id, inverse_of: :publish_target

    validates :key, presence: true, uniqueness: { case_sensitive: false }
    validates :label, presence: true
    validates :provider, inclusion: { in: ->(_target) { Dam::Publishing.provider_keys } }
    validates :http_method, inclusion: { in: HTTP_METHODS }
    validates :body_style, inclusion: { in: BODY_STYLES.keys }
    validates :endpoint_url, presence: true, if: :custom_endpoint?
    validate :endpoint_is_reachable_kind_of_url, if: -> { endpoint_url.present? }

    before_validation :derive_key, on: :create
    before_validation :place_last, on: :create

    scope :enabled, -> { where(enabled: true) }
    scope :ordered, -> { order(:position, :label) }
    scope :of_provider, ->(provider) { where(provider: provider) }

    # Everywhere this asset could actually go. Read as a list rather than a
    # scope because eligibility is the adapter's answer, not a column.
    def self.open_to(asset)
      enabled.ordered.select { |target| target.refusal_reason(asset).nil? }
    end

    def to_s = label

    def adapter_class = Dam::Publishing.adapter(provider)

    # A provider the form has not saved yet may be anything at all, and the
    # validations below run before the one that rejects it — so everything
    # that asks the adapter a question has to survive not having one.
    def known_provider? = Dam::Publishing.provider_keys.include?(provider)

    def provider_label = known_provider? ? adapter_class.label : provider.to_s.titleize

    def media_types = known_provider? ? adapter_class.media_types : []

    def oauth? = known_provider? && adapter_class.oauth?

    def custom_endpoint? = known_provider? && !adapter_class.oauth?

    def account_prompt = known_provider? ? adapter_class.account_prompt : nil

    def privacy_options = known_provider? ? adapter_class.privacy_options : {}

    def connected? = oauth? ? oauth_access_token.present? : endpoint_url.present?

    # A token that has run out is not a disconnected target: the refresh token
    # is still good, and the next publish renews it. Only a provider that
    # cannot renew — Vimeo issues no refresh token — leaves someone to redo it.
    def token_expired? = oauth_expires_at.present? && oauth_expires_at.past?

    def token_renewable? = oauth_refresh_token.present? || (known_provider? && adapter_class.token_lifetime == :permanent)

    def needs_reconnecting? = oauth? && (!connected? || (token_expired? && !token_renewable?))

    # Why this target will not take this asset, or nil when it will. One
    # method so the picker, the create action and the status pill cannot
    # disagree about what "closed" means.
    def refusal_reason(asset = nil)
      return 'disabled' unless enabled?
      return 'not connected yet' if needs_reconnecting?
      return 'no endpoint set' if custom_endpoint? && endpoint_url.blank?
      return nil if asset.blank?
      return "does not take #{asset.media_type} files" unless media_types.include?(asset.media_type)
      return 'the original file is not reachable' unless asset.original_available?

      nil
    end

    # Headers for a custom endpoint, typed one per line. Anything without a
    # colon is skipped rather than sent as a nameless header.
    def header_pairs
      headers.to_s.lines.filter_map do |line|
        name, value = line.split(':', 2)
        next if name.blank? || value.blank?

        [name.strip, value.strip]
      end.to_h
    end

    def last_publication = publications.order(created_at: :desc).first

    # Stores what an OAuth exchange or refresh came back with. A refresh that
    # returns no new refresh token keeps the one we already hold — Google only
    # issues it on the first consent, and dropping it would disconnect the
    # target on its first renewal.
    def record_connection!(tokens, actor: nil)
      assign_attributes(
        oauth_access_token: tokens[:access_token],
        oauth_refresh_token: tokens[:refresh_token].presence || oauth_refresh_token,
        oauth_expires_at: tokens[:expires_in].present? ? Time.current + tokens[:expires_in].to_i.seconds : nil,
        oauth_scope: tokens[:scope].presence || oauth_scope
      )
      if actor
        self.connected_at = Time.current
        self.connected_by_id = actor.employee_id.to_s
        self.connected_by_name = "#{actor.first_name} #{actor.last_name}".strip.presence
      end
      save!
    end

    def disconnect!
      update!(oauth_access_token: nil, oauth_refresh_token: nil, oauth_expires_at: nil,
              oauth_scope: nil, connected_at: nil, connected_by_id: nil, connected_by_name: nil)
    end

    private

    def derive_key
      self.key = label.to_s.parameterize(separator: '_') if key.blank?
    end

    def place_last
      self.position = (self.class.maximum(:position) || 0) + 1 if position.to_i.zero?
    end

    # Typed by hand, so it is checked here rather than at the point the runner
    # opens a connection to it.
    def endpoint_is_reachable_kind_of_url
      uri = URI.parse(endpoint_url)
      raise URI::InvalidURIError unless uri.is_a?(URI::HTTP) && uri.host.present?
    rescue URI::InvalidURIError
      errors.add(:endpoint_url, 'must be a http:// or https:// address')
    end
  end
end
