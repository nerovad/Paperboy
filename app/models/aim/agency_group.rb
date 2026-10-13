# frozen_string_literal: true

module Aim
  # An agency group (#131): whose invoices a set of Fiscal people, Group Admins
  # and Fiscal settings serve. Every COA agency has its own group, made when
  # first needed and named from the COA. An AIM Admin may make custom groups
  # of an agency's BUs; a BU ticked into a custom group leaves its agency's
  # group, so every BU is in exactly one group and every invoice finds one
  # (Aim::AgencyGroups).
  #
  # Not Aim::Group: inside module Aim that name would hide Paperboy's ACL
  # Group, which Aim::Users reads.
  class AgencyGroup < Record
    ROLES = { 'admin' => 'Group Admin', 'fiscal' => 'Fiscal' }.freeze
    EXPORT_FORMATS = { 'csv' => 'Comma-separated, UTF-8', 'tab' => 'Tab-separated, UTF-16' }.freeze

    has_many :units, class_name: 'Aim::AgencyGroupUnit', inverse_of: :agency_group, dependent: :delete_all
    has_many :roles, class_name: 'Aim::AgencyGroupRole', inverse_of: :agency_group, dependent: :delete_all
    # Fiscal also processes: the groups this one's Fiscal people work too.
    has_many :coverages, class_name: 'Aim::AgencyGroupCoverage', inverse_of: :agency_group, dependent: :delete_all
    has_many :covered_groups, through: :coverages
    before_destroy { Aim::AgencyGroupCoverage.where(covered_group_id: id).delete_all }

    before_validation do
      self.name = name.to_s.squish
      self.agency_id = agency_id.to_s.strip.upcase
    end

    validates :name, presence: true, length: { maximum: 100 }, uniqueness: true
    validates :agency_id, presence: true
    validates :agency_id, uniqueness: { conditions: -> { where(custom: false) }, message: 'already has its group' },
                          unless: :custom
    validates :export_format, inclusion: { in: EXPORT_FORMATS.keys }
    validate :fiscal_settings_known

    scope :agency_wide, -> { where(custom: false) }
    scope :by_name, -> { order(:agency_id, :custom, :name) }

    # The agency's own group, made from the COA's name when it has none yet.
    def self.for_agency!(agency_id)
      agency_id = agency_id.to_s.upcase
      agency_wide.find_by(agency_id: agency_id) || create!(agency_id: agency_id, custom: false, name: agency_name(agency_id))
    rescue ActiveRecord::RecordNotUnique
      agency_wide.find_by!(agency_id: agency_id)
    end

    def self.agency_name(agency_id)
      name = Coa::Agency.where(agency_id: agency_id).pick(:name)
      [agency_id, (Aim::Units.tidy(name) if name)].compact.join(' · ')
    rescue ActiveRecord::ActiveRecordError
      agency_id
    end

    # Every agency AIM serves has its group. Safe to run again.
    def self.ensure_agency_groups!(agencies = Aim::Units.new.agencies)
      have = agency_wide.pluck(:agency_id).to_set
      agencies.reject { |agency| have.include?(agency) }.each { |agency| for_agency!(agency) }
    end

    def kind_label = custom ? 'Custom group' : 'Agency group'

    def people_with(role) = roles.select { |r| r.role == role }.map(&:employee_id)

    # Fiscal settings. Blank means AIM's defaults, which are GSA's.

    # The report's layout, kept as JSON in export_columns:
    #   {"columns": ["Invoice Number", ...], "headers": {"Invoice Number": "Inv #"}}
    # A bare list (the first form) still reads. Blank is AIM's report as is.
    def export_settings
      raw = JSON.parse(export_columns.presence || 'null')
      raw = { 'columns' => raw } if raw.is_a?(Array)
      raw.is_a?(Hash) ? raw : {}
    rescue JSON::ParserError
      {}
    end

    # The report's columns, in the group's order.
    def export_column_list
      list = Array(export_settings['columns']).map(&:to_s).uniq & Aim::FiscalExport::COLUMNS
      list.any? ? list : Aim::FiscalExport::COLUMNS
    end

    def export_column_list=(names)
      store_export(columns: Array(names).map(&:to_s).uniq & Aim::FiscalExport::COLUMNS)
    end

    # Every column, the group's first in its order, then the ones left out.
    def export_column_order = export_column_list | Aim::FiscalExport::COLUMNS

    # { column => the header the group's report gives it }, renamed ones only.
    def export_headers
      headers = export_settings['headers']
      headers.is_a?(Hash) ? headers.slice(*Aim::FiscalExport::COLUMNS).transform_values { |v| v.to_s.squish }.compact_blank : {}
    end

    def export_headers=(names)
      renamed = names.to_h.transform_keys(&:to_s).transform_values { |v| v.to_s.squish }
                     .select { |column, header| Aim::FiscalExport::COLUMNS.include?(column) && header.present? && header != column }
      store_export(headers: renamed)
    end

    def export_header(column) = export_headers.fetch(column, column)

    def hold_reason_list = lines(hold_reasons)

    def tag_suggestion_list
      tag_suggestions.nil? ? Aim::FiscalRecord::TAG_SUGGESTIONS : lines(tag_suggestions)
    end

    def required_field_list = required_fields.to_s.split(',').map(&:strip) & Aim::FiscalRecord::EDITABLE_FIELDS

    def required_field_list=(names)
      self.required_fields = (Array(names).map(&:to_s) & Aim::FiscalRecord::EDITABLE_FIELDS).join(',').presence
    end

    private

    def lines(text) = text.to_s.lines.map(&:squish).compact_blank.uniq

    # Nothing stored when the report is AIM's own; no columns ticked is an error.
    def store_export(columns: nil, headers: nil)
      settings = export_settings
      columns ||= settings.key?('columns') ? Array(settings['columns']) : Aim::FiscalExport::COLUMNS
      headers ||= export_headers
      self.export_columns = if columns == Aim::FiscalExport::COLUMNS && headers.empty? then nil
                            else { 'columns' => columns, 'headers' => headers }.to_json
                            end
    end

    def fiscal_settings_known
      return if export_columns.blank?

      columns = export_settings['columns']
      errors.add(:base, 'Pick at least one column for the report') unless columns.is_a?(Array) && columns.intersect?(Aim::FiscalExport::COLUMNS)
    end
  end
end
