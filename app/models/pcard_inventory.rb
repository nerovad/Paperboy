class PcardInventory < ApplicationRecord
  belongs_to :pcard_request_form, optional: true

  validates :last_name, :first_name, presence: true

  scope :active, -> { where(canceled_date: nil) }
  scope :canceled, -> { where.not(canceled_date: nil) }
  scope :search, ->(query) {
    where("last_name LIKE :q OR first_name LIKE :q OR card_number LIKE :q OR agency LIKE :q",
          q: "%#{query}%")
  }

  def full_name
    "#{first_name} #{last_name}"
  end

  def active?
    canceled_date.nil?
  end
end
