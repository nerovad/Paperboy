class PcardInventory < ApplicationRecord
  belongs_to :pcard_request_form, optional: true

  encrypts :card_number

  validates :last_name, :first_name, presence: true

  before_save :set_card_last_four

  scope :active, -> { where(canceled_date: nil) }
  scope :canceled, -> { where.not(canceled_date: nil) }
  scope :search, ->(query) {
    where("last_name LIKE :q OR first_name LIKE :q OR card_last_four LIKE :q OR agency LIKE :q",
          q: "%#{query}%")
  }

  def masked_card_number
    card_last_four.present? ? "****#{card_last_four}" : nil
  end

  def full_name
    "#{first_name} #{last_name}"
  end

  def active?
    canceled_date.nil?
  end

  private

  def set_card_last_four
    if card_number.present? && card_number.length >= 4
      self.card_last_four = card_number.last(4)
    elsif card_number.blank?
      self.card_last_four = nil
    end
  end
end
