# frozen_string_literal: true

module Dam
  # One asset, on its way to one publish target, and what became of it.
  #
  # Rows are never deleted and never overwritten by a retry: publishing the
  # same video twice makes two rows, because it made two videos. A failure is
  # kept for the same reason a success is — the useful question months later
  # is "did this go up, when, and under what link", and a row that was tidied
  # away cannot answer it.
  class Publication < ApplicationRecord
    STATUSES = %w[queued running succeeded failed cancelled].freeze
    OPEN_STATUSES = %w[queued running].freeze

    # How long after a publish finishes a provider may still fetch the bytes
    # from the link we handed it. Instagram fetches within seconds; an hour is
    # slack for a slow queue, not an access window anyone can plan around.
    PUBLIC_TOKEN_GRACE = 1.hour

    belongs_to :asset, class_name: 'Dam::Asset', inverse_of: :publications
    belongs_to :publish_target, class_name: 'Dam::PublishTarget', inverse_of: :publications

    validates :status, inclusion: { in: STATUSES }
    validates :title, presence: true

    before_validation :snapshot_subjects, on: :create

    scope :newest_first, -> { order(created_at: :desc) }
    scope :open, -> { where(status: OPEN_STATUSES) }
    scope :succeeded, -> { where(status: 'succeeded') }
    scope :failed, -> { where(status: 'failed') }
    scope :by_employee, ->(employee_id) { where(requested_by_id: employee_id.to_s) }

    # Filtering by state belongs in SQL rather than after pagination, or "show
    # me what failed" returns only the failures that fell on this page.
    def self.in_state(state)
      return all unless STATUSES.include?(state.to_s)

      where(status: state.to_s)
    end

    def open? = OPEN_STATUSES.include?(status)

    def succeeded? = status == 'succeeded'

    def failed? = status == 'failed'

    def duration
      return nil if started_at.blank?

      ((finished_at || Time.current) - started_at).round
    end

    def tag_list = tags.to_s.split(',').map(&:strip).compact_blank

    def tag_list=(values)
      self.tags = Array(values).map(&:to_s).map(&:strip).compact_blank.join(', ')
    end

    # Whether the link handed to a provider that fetches rather than receives
    # is still good. Tied to the publish itself, so nothing is readable before
    # the job starts or long after it stops.
    def public_link_live?
      return false if public_token.blank?
      return true if open?

      finished_at.present? && finished_at > PUBLIC_TOKEN_GRACE.ago
    end

    def ensure_public_token!
      update!(public_token: SecureRandom.urlsafe_base64(24)) if public_token.blank?
      public_token
    end

    def start!
      update!(status: 'running', started_at: Time.current, attempts: attempts.to_i + 1, error: nil)
    end

    def succeed!(external_id: nil, external_url: nil, response_code: nil)
      update!(status: 'succeeded', external_id: external_id, external_url: external_url,
              response_code: response_code, finished_at: Time.current)
      publish_target.update_columns(last_published_at: Time.current, updated_at: Time.current)
    end

    def fail!(message, response_code: nil)
      update!(status: 'failed', error: message.to_s.truncate(2000),
              response_code: response_code, finished_at: Time.current)
    end

    # Append one line to the run log, without saving: a delivery writes many
    # lines and one row write at the end of it is enough.
    def append_log(line)
      self.log = [log, "[#{Time.current.strftime('%H:%M:%S')}] #{line}"].compact_blank.join("\n")
    end

    # A fresh attempt rather than a rewrite of this one, so the history keeps
    # both the failure and whatever the retry did.
    def duplicate_for_retry(actor: nil)
      self.class.new(
        asset: asset, publish_target: publish_target, title: title, description: description,
        tags: tags, privacy: privacy, status: 'queued', queued_at: Time.current,
        requested_by_id: actor&.employee_id&.to_s,
        requested_by_name: actor && "#{actor.first_name} #{actor.last_name}".strip.presence
      )
    end

    private

    # Copied at create so a publication of a since-deleted asset, or of a
    # target somebody renamed, still says what it was.
    def snapshot_subjects
      self.asset_title ||= asset&.title
      self.target_label ||= publish_target&.label
      self.provider ||= publish_target&.provider
      self.queued_at ||= Time.current
    end
  end
end
