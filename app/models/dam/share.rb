# frozen_string_literal: true

module Dam
  # One outbound share of an asset or a collection — what My Shares lists.
  #
  # Rows are never deleted when a share ends; revoking stamps revoked_at. The
  # screen is a history, and "who did I send this to, and when" is the question
  # it exists to answer.
  class Share < ApplicationRecord
    PERMISSIONS = { 'view' => 'View only', 'download' => 'View and download' }.freeze

    belongs_to :subject, polymorphic: true

    validates :token, presence: true, uniqueness: true
    validates :permission, inclusion: { in: PERMISSIONS.keys }

    before_validation :ensure_token, on: :create
    before_validation :snapshot_subject_label, on: :create

    scope :newest_first, -> { order(created_at: :desc) }
    scope :by_employee, ->(employee_id) { where(shared_by_id: employee_id.to_s) }

    scope :revoked, -> { where.not(revoked_at: nil) }
    scope :expired, -> { where(revoked_at: nil).where.not(expires_at: nil).where(expires_at: ...Time.current) }
    scope :active, -> { where(revoked_at: nil).where(expires_at: [nil, Time.current..]) }

    # Filtering by state has to happen in SQL, not after pagination — otherwise
    # "show me my active shares" returns only the active ones that happen to
    # fall on the page you are looking at.
    def self.in_state(state)
      case state
      when 'active' then active
      when 'expired' then expired
      when 'revoked' then revoked
      else all
      end
    end

    def permission_label = PERMISSIONS.fetch(permission, permission)

    def revoked? = revoked_at.present?

    def expired? = expires_at.present? && expires_at.past?

    def active? = !revoked? && !expired?

    def state
      return 'revoked' if revoked?
      return 'expired' if expired?

      'active'
    end

    def recipient_list
      recipients.to_s.split(/[\n,;]/).map(&:strip).compact_blank
    end

    def recipient_list=(values)
      self.recipients = Array(values).map(&:to_s).map(&:strip).compact_blank.join("\n")
    end

    def revoke!
      update!(revoked_at: Time.current)
    end

    private

    def ensure_token
      self.token ||= SecureRandom.urlsafe_base64(24)
    end

    # The label is copied rather than read through the association so a share
    # of a since-deleted asset still says what it was.
    def snapshot_subject_label
      self.subject_label ||= subject.try(:title) || subject.try(:name)
    end
  end
end
