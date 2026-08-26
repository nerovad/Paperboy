# frozen_string_literal: true

# app/services/critical_information_console_cards.rb
#
# The card list behind the CIR authorization console's index: one card per site
# on the Critical Information Reporting form, carrying the incident manager who
# covers it, or nothing at all.
#
# Listing the whole catalogue rather than just the saved rows is the point of
# the screen. An unrouted location is invisible in a list of authorizations, and
# 41 of the form's 212 sites arrived here with no manager — a report from one of
# them reaches nobody's inbox.
class CriticalInformationConsoleCards
  Card = Struct.new(:location, :label, :authorization, keyword_init: true) do
    def assigned?
      !authorization.nil?
    end
  end

  # `assignment` is 'assigned', 'unassigned' or nil for everything.
  def initialize(authorizations, locations: [], employee_ids: [], assignment: nil)
    @by_location  = authorizations.index_by { |a| a.location.to_s }
    @locations    = Array(locations)
    @employee_ids = Array(employee_ids)
    @assignment   = assignment
  end

  def to_a
    catalogue_cards + retired_cards
  end

  private

  attr_reader :by_location, :locations, :employee_ids, :assignment

  def catalogue = CriticalInformationLocation::ALL

  def catalogue_cards
    catalogue.filter_map do |location|
      next unless listed?(location)

      authorization = by_location[location]
      next unless show?(authorization)

      Card.new(location: location, label: location, authorization: authorization)
    end
  end

  # Rows whose location has dropped out of the catalogue. Shown so they can be
  # seen and removed rather than quietly routing reports nobody can find. They
  # are assigned by definition, so they never survive the "unassigned" filter.
  def retired_cards
    return [] if assignment == 'unassigned'

    (by_location.keys - catalogue).select { |location| listed?(location) }.sort.map do |location|
      Card.new(location: location, label: "#{location} (no longer on the form)",
               authorization: by_location[location])
    end
  end

  def listed?(location)
    locations.empty? || locations.include?(location)
  end

  # An uncovered site has no row, so neither the manager filter nor the
  # "assigned" filter can be satisfied by one.
  def show?(authorization)
    if authorization.nil?
      employee_ids.empty? && assignment != 'assigned'
    else
      assignment != 'unassigned'
    end
  end
end
