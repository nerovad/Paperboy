# frozen_string_literal: true

module Aim
  # Agencies and budget units, read from the Chart of Accounts so AIM's lists
  # and labels are always the COA's (Joshua, 2026-09-25). Which agencies AIM
  # offers is not a setting: it is the agencies of the people who work AIM, read
  # from GSABSS, so adding Sheriff's AP people brings Sheriff's units with them.
  # GSABSS spells an agency with a trailing V (GSAV) where the COA does not
  # (GSA); Coa::Agency.normalize_id translates.
  #
  # Three unit numbers belong to more than one agency in the COA. An invoice
  # stores only its unit, so for those the first agency AIM serves is assumed;
  # storing the agency on the invoice belongs to item b.
  class Units
    Unit = Struct.new(:agency, :unit, :name, keyword_init: true) do
      def label = "#{unit} · #{Units.tidy(name)}"
    end

    SMALL_WORDS = %w[and of the for to in on at by or].freeze

    # The COA's names are in capitals: "WAREHOUSE AND DISTRIBUTION SERVICES",
    # "GSA ADMINISTRATION". Title case, with small words lower and agency
    # codes (the COA's own, GSA, HCA...) left in capitals.
    def self.tidy(name)
      words = name.to_s.squish.split
      words.each_with_index.map do |word, index|
        if acronyms.include?(word.upcase) then word.upcase
        elsif index.positive? && SMALL_WORDS.include?(word.downcase) then word.downcase
        else word.capitalize
        end
      end.join(' ')
    end

    def self.acronyms
      @acronyms ||= Coa::Agency.pluck(:agency_id).to_set { |id| id.to_s.upcase }
    rescue ActiveRecord::ActiveRecordError
      Set.new
    end

    FALLBACK_AGENCIES = %w[GSA].freeze

    # The agencies AIM serves: those of the people who work AIM.
    def agencies
      @agencies ||= begin
        codes = Employee.where(id: Aim::Users.all.select(:id)).distinct.pluck(:agency)
        found = codes.filter_map { |code| Coa::Agency.normalize_id(code) }.uniq.sort
        found.presence || FALLBACK_AGENCIES
      rescue ActiveRecord::ActiveRecordError
        FALLBACK_AGENCIES
      end
    end

    # { "GSA" => "General Services Agency", ... }
    def agency_names
      @agency_names ||= Coa::Agency.where(agency_id: agencies).pluck(:agency_id, :name)
                                   .to_h { |id, name| [id, Units.tidy(name)] }
    end

    def agency_label(agency) = [agency, agency_names[agency]].compact.join(' · ')

    # Active COA units of the agencies AIM serves, in agency then unit order.
    def all
      @all ||= Coa::Unit.where(agency_id: agencies, active: true).order(:agency_id, :unit_id)
                        .pluck(:agency_id, :unit_id, :long_name)
                        .map { |agency, unit, name| Unit.new(agency: agency, unit: unit, name: name) }
                        .uniq(&:unit)
    end

    def units_of(agency) = all.select { |u| u.agency == agency }.map(&:unit)

    def agency_of(unit) = by_unit[unit.to_s]&.agency

    # "4703 · Maintenance", or the bare number for a unit the COA lacks.
    def label(unit)
      return 'No BU' if unit.blank?

      by_unit[unit.to_s]&.label || other_label(unit.to_s)
    end

    # [label, unit] pairs, optionally limited to some units.
    def options(only: nil) = pick(all, only).map { |u| [u.label, u.unit] }

    # For grouped_options_for_select: [[agency label, [[label, unit], ...]], ...]
    def grouped_options(only: nil)
      pick(all, only).group_by(&:agency).map { |agency, units| [agency_label(agency), units.map { |u| [u.label, u.unit] }] }
    end

    private

    def by_unit = (@by_unit ||= all.index_by(&:unit))

    def pick(units, only) = only.nil? ? units : units.select { |u| only.include?(u.unit) }

    # A unit outside the agencies AIM serves, labelled from the COA anyway.
    def other_label(unit)
      @other_labels ||= {}
      @other_labels[unit] ||= begin
        name = Coa::Unit.where(unit_id: unit).pick(:long_name)
        name ? Unit.new(unit: unit, name: name).label : unit
      end
    end
  end
end
