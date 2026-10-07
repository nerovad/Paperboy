# frozen_string_literal: true

# Who to email about the rows that carry one value of a column on a Records
# table -- Fleet Vehicles' Agency "GSA" goes to these people. Typed in by the
# table's editors from the grid's Email dialog, and shared by every email rule
# on the table that splits by that column (see RecordsEmailRule).
class RecordsEmailContact < ApplicationRecord
  normalizes :email, with: ->(email) { email.to_s.strip.downcase }
  normalizes :match_value, with: ->(value) { value.to_s.strip }

  validates :table_slug, :column_name, :match_value, presence: true
  validates :email, presence: true,
                    uniqueness: { scope: %i[table_slug column_name match_value], case_sensitive: false,
                                  message: 'is already a contact for that value' }
  validate :column_must_be_on_the_table
  validate :email_must_be_a_county_employee

  scope :for_table, ->(slug) { where(table_slug: slug).order(:column_name, :match_value, :email) }

  # Values are matched the way a person reads them: "gsa " is "GSA".
  def self.key(value) = value.to_s.strip.downcase

  # { "gsa" => ["a@x.org", "b@x.org"] } for one column of a table.
  def self.directory(table_slug, column_name)
    where(table_slug: table_slug, column_name: column_name)
      .group_by { |contact| key(contact.match_value) }
      .transform_values { |contacts| contacts.map(&:email).uniq }
  end

  def column
    RegistryTable.find(table_slug)&.columns&.find { |c| c.name.to_s == column_name }
  end

  private

  def column_must_be_on_the_table
    return if table_slug.blank? || column_name.blank?

    errors.add(:column_name, 'is not a column on this table') unless column
  end

  def email_must_be_a_county_employee
    return if email.blank?

    errors.add(:email, "#{email} is not a county employee's address") if RecordsEmailRecipients.county([email]).empty?
  end
end
