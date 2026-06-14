# Contractors are non-Active-Directory users provisioned by a system admin. They
# live in the Paperboy DB (GSABSS Employees is read-only) but deliberately mirror
# the slice of the Employee interface the workflow/prefill/permission code reads,
# so a contractor can be a form *submitter* anywhere an employee can.
#
# Identity: the PK is reseeded to start at 1,000,000,000 (see the migration) so
# contractor ids never collide with Employee ids. That lets:
#   * submissions store the submitter as a plain integer (no discriminator), and
#   * `Submitter.resolve` fall back from Employee to Contractor by id, and
#   * Employee_Groups / the whole ACL pipeline be reused unchanged.
#
# Contractors are only ever submitters, never approvers — supervisor_id points at
# a real Employee who does the approving.
class Contractor < ApplicationRecord
  # Lets routing/prefill code call `.employee_id` on a resolved submitter exactly
  # as it would on an Employee (Employee aliases employee_id -> id too).
  alias_attribute :employee_id, :id

  has_secure_password validations: false

  # Signed, stateless tokens — no token columns. Both auto-invalidate once the
  # password is set (the digest enters the signing payload), so a used welcome
  # link can't be replayed. Setup links live longer than reset links.
  generates_token_for :password_setup, expires_in: 7.days do
    password_salt&.last(10)
  end
  generates_token_for :password_reset, expires_in: 2.hours do
    password_salt&.last(10)
  end

  DEFAULT_VALIDITY = 1.year

  validates :first_name, :last_name, presence: true
  validates :email, presence: true, uniqueness: { case_sensitive: false },
                    format: { with: URI::MailTo::EMAIL_REGEXP }
  # Business unit + supervisor + expiry are required (admin sets them at
  # creation). Enforced here because the unit/supervisor selects are
  # Choices-enhanced and can't rely on the HTML `required` attribute. Phone is
  # intentionally optional.
  validates :agency, :unit, :supervisor_id, :expires_at, presence: true

  before_validation :normalize_email
  before_validation :set_default_expiry, on: :create

  scope :active, -> { where(active: true) }

  # A contractor may sign in only while active, unexpired, and password-set.
  def login_allowed?
    active? && !expired? && password_digest.present?
  end

  def expired?
    expires_at.present? && expires_at.past?
  end

  # Eligible to receive a password-reset link (may not have set a password yet,
  # but must be active and unexpired).
  def resettable?
    active? && !expired?
  end

  def deactivate!
    update!(active: false)
  end

  def full_name
    "#{first_name} #{last_name}".strip
  end

  # --- Submitter interface parity with Employee ---------------------------
  # work_phone, agency, department, unit, supervisor_id, first_name, last_name,
  # email are already columns; nothing extra needed. `contractor?` lets the few
  # spots that care (e.g. session) distinguish the source.
  def contractor?
    true
  end

  private

  def normalize_email
    self.email = email.to_s.strip.downcase.presence
  end

  def set_default_expiry
    self.expires_at ||= Time.current + DEFAULT_VALIDITY
  end
end
