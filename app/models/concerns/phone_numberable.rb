module PhoneNumberable
  extend ActiveSupport::Concern

  included do
    before_validation :normalize_phone!
    validate :phone_has_ten_digits
  end

  private

  def normalize_phone!
    # store digits-only; format in views/PDFs
    self.phone = phone.to_s.gsub(/\D/, "")
  end

  def phone_has_ten_digits
    errors.add(:phone, "must have exactly 10 digits") unless phone.present? && phone.length == 10
  end
end
