# frozen_string_literal: true

class PcardInventory < ApplicationRecord
  include Registry

  belongs_to :pcard_request_form, optional: true

  encrypts :card_number

  validates :last_name, :first_name, presence: true

  before_save :set_card_last_four

  scope :active, -> { where(canceled_date: nil) }
  scope :canceled, -> { where.not(canceled_date: nil) }
  scope :search, lambda { |query|
    where('last_name LIKE :q OR first_name LIKE :q OR card_last_four LIKE :q OR agency LIKE :q',
          q: "%#{query}%")
  }

  # Records table definition — surfaced as the "records:pcard" page.
  registry_table slug: 'pcard', label: 'P-Cards', permission: 'pcard_admin',
                 dropdown_key: 'pcard_inventory', route: :pcard_inventory_index_path

  registry_column :last_name, label: 'Last Name', kind: :text, filter: :search
  registry_column :first_name, label: 'First Name', kind: :text
  registry_column :agency, label: 'Agency/Dept', kind: :text, filter: :select
  registry_column :division, label: 'Division', kind: :text, filter: :select
  registry_column :phone, kind: :text, sortable: false
  registry_column :single_purchase_limit, label: 'Single Limit', kind: :currency
  registry_column :monthly_limit, label: 'Monthly Limit', kind: :currency
  registry_column :masked_card_number, label: 'Card #', kind: :text, sortable: false
  registry_column :issued_date, label: 'Issued', kind: :date
  registry_column :expiration_date, label: 'Expires', kind: :date
  registry_column :status_label, label: 'Status', kind: :status, sortable: false

  # Auto-created when a P-Card request is approved (RecordIngestion). Mirrors
  # the fields the request form carries; org codes resolve to display names.
  registry_fed_by PcardRequestForm,
                  pcard_request_form: ->(form) { form },
                  first_name: ->(form) { form.name.to_s.split(' ', 2).first },
                  last_name: ->(form) { form.name.to_s.split(' ', 2).last },
                  agency: ->(form) { Agency.find_by(agency_id: form.agency)&.long_name || form.agency },
                  division: ->(form) { Division.find_by(division_id: form.division)&.long_name || form.division },
                  phone: :phone,
                  approver_name: ->(form) { form.try(:approver_name) },
                  single_purchase_limit: ->(form) { form.try(:single_purchase_limit) },
                  monthly_limit: ->(form) { form.try(:spending_limit_30_day) }

  def masked_card_number
    card_last_four.present? ? "****#{card_last_four}" : nil
  end

  def full_name
    "#{first_name} #{last_name}"
  end

  def active?
    canceled_date.nil?
  end

  # Derived lifecycle label for the Records "Status" column.
  def status_label
    return 'Canceled' if canceled_date.present?
    return 'Expired' if expiration_date.present? && expiration_date < Date.current

    'Active'
  end

  # Badge category for the Records "Status" column (drives the badge color).
  def status_badge_category
    return :cancelled if canceled_date.present?
    return :denied if expiration_date.present? && expiration_date < Date.current

    :approved
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
