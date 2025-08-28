class ProbationTransferRequest < ApplicationRecord
  include PhoneNumberable

  STATUS_MAP = {
    0 => "submitted",
    1 => "manager_approved",
    2 => "denied",
    3 => "sent_to_security"
  }

  scope :for_employee, ->(employee_id) { where(employee_id: employee_id.to_s) }

  scope :not_canceled, -> { where(canceled_at: nil) }
  scope :not_expired,  -> { where("expires_at IS NULL OR expires_at > ?", Time.current) }
  scope :active,       -> { where(status: 0).not_canceled.not_expired } # “submitted” and still valid

  def status_label
    STATUS_MAP[status]
  end

  def submitted?;          status == 0; end
  def manager_approved?;   status == 1; end
  def denied?;             status == 2; end
  def sent_to_security?;   status == 3; end

def ensure_expires!
  return if expires_at.present?
  base = created_at || Time.current
  update_columns(expires_at: base + 1.year, updated_at: Time.current)
end

def cancel!(reason:)
  return if canceled_at.present?
  update_columns(canceled_at: Time.current, canceled_reason: reason, updated_at: Time.current)
end

def expire_if_due!
  return if canceled_at.present?
  return if expires_at.blank? || expires_at > Time.current
  update_columns(canceled_at: Time.current, canceled_reason: "expired", updated_at: Time.current)
end
end
