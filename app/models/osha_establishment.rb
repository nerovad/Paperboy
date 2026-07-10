class OshaEstablishment < ApplicationRecord
  has_many :entries, class_name: 'Osha300aEntry', dependent: :destroy

  SIZE_OPTIONS = {
    1 => 'Less than 20 employees',
    21 => '20-99 employees',
    22 => '100-249 employees',
    3 => '250+ employees'
  }.freeze

  ESTABLISHMENT_TYPE_OPTIONS = {
    1 => 'Not a government entity',
    2 => 'State Government',
    3 => 'Local Government'
  }.freeze

  validates :name, :street_address, :city, :state, :zip, :naics_code, :size, presence: true
  validates :name, uniqueness: true, length: { maximum: 100 }
  validates :ein, presence: true, format: { with: /\A\d{9}\z/, message: 'must be 9 digits, no dashes' }
  validates :state, length: { is: 2 }
  validates :zip, format: { with: /\A\d{5}(\d{4})?\z/, message: 'must be 5 or 9 digits' }
  validates :naics_code, numericality: { only_integer: true }, format: { with: /\A\d{6}\z/, message: 'must be 6 digits' }
  validates :size, inclusion: { in: SIZE_OPTIONS.keys }
  validates :establishment_type, inclusion: { in: ESTABLISHMENT_TYPE_OPTIONS.keys }, allow_nil: true
  validates :industry_description, length: { maximum: 300 }, allow_blank: true
  validates :company_name, length: { maximum: 100 }, allow_blank: true

  def self.primary
    first
  end
end
