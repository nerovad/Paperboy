# frozen_string_literal: true

# app/models/critical_information_location.rb
#
# One site the Critical Information Reporting form offers in its "Where:
# Location" dropdown, and the unit the CIR authorization console assigns
# incident managers over.
#
# The catalogue used to be a frozen array in this file, so opening or closing a
# site took a deploy. It is a table now, managed from the console.
#
# `name` is data, not a label: it is stored verbatim in
# critical_information_reportings.location and in
# critical_information_authorizations.location. A site can be added or deleted
# but deliberately not renamed — a rename would orphan every report already
# filed under the old spelling, and reports are records of what was submitted.
# Deleting a site takes its authorization with it and leaves those reports
# alone.
class CriticalInformationLocation < ApplicationRecord
  validates :name, presence: true
  validates :name, uniqueness: { case_sensitive: false, message: 'is already on the form' }

  scope :ordered, -> { order(:name) }

  # The authorization covering this site, if anyone does. Joined on the name
  # rather than an id because that string is what the form submits and what
  # every report carries.
  def authorization
    CriticalInformationAuthorization.find_by(location: name)
  end

  # Every site on the form, in dropdown order.
  def self.names
    ordered.pluck(:name)
  end

  # [[label, value], ...] for a plain location picker. The CIR form appends the
  # assigned manager to each label; the console does not, because it shows the
  # manager on the card itself.
  def self.options
    names.map { |name| [name, name] }
  end

  def self.exists_named?(name)
    where(name: name.to_s).exists?
  end
end
