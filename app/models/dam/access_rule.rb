# frozen_string_literal: true

module Dam
  # Governance over part of the library: which assets, who may see them, and
  # what those people may do with them beyond looking.
  #
  # A rule has two halves:
  #
  # * **Which assets.** An org window on the asset — its agency / division /
  #   department / unit, picked with the same cascade forms use — and any
  #   number of custom-metadata conditions, stored as the rows Advanced
  #   Search builds (Dam::MetadataFilter). Every part must hold for an asset
  #   to match.
  # * **Who.** Its grantees: groups, single employees, or everyone inside an
  #   org level (Dam::AccessRuleGrantee).
  #
  # The library stays open by default. An asset no active rule matches is
  # visible to everyone who holds Digital Asset Management, as it always was.
  # The moment one rule matches it, only people covered by a matching rule
  # see it at all, and each capability flag widens what they may do. Several
  # matching rules add up: whatever any of them allows the viewer, they may do.
  # Dam::Access is where all of this is turned into queries.
  #
  # A condition is always read as it was written. One on a field since
  # deleted, or since retyped so its operator no longer applies, still
  # matches the values assets carry under that key: changing the field
  # editor must never quietly lift or reshape a restriction. Should a
  # condition still not be readable, the rule fails closed: it keeps
  # restricting on whatever of it stands and grants nothing until someone
  # fixes it. Only when nothing of it stands does it restrict nothing, rather
  # than the whole library.
  class AccessRule < ApplicationRecord
    self.table_name = 'dam_access_rules'

    CAPABILITY_LABELS = {
      download: 'Download',
      share: 'Share',
      publish: 'Publish',
      edit: 'Edit and archive'
    }.freeze
    CAPABILITIES = CAPABILITY_LABELS.keys.freeze

    ORG_LEVELS = ::FormSearch::ORG_LEVELS

    has_many :grantees, class_name: 'Dam::AccessRuleGrantee', foreign_key: :rule_id,
                        inverse_of: :rule, dependent: :delete_all

    before_validation :normalize_org_window

    validates :name, presence: true
    validate :narrows_the_library
    validate :conditions_make_sense

    scope :active, -> { where(active: true) }
    scope :ordered, -> { order(:name) }

    # The metadata conditions as Advanced Search rows:
    # [{ "field" => "usage_rights", "operator" => "equals", "value" => "Internal only" }].
    def condition_rows
      parsed = conditions.present? ? JSON.parse(conditions) : []
      parsed.is_a?(Array) ? parsed : []
    rescue JSON::ParserError
      []
    end

    # Takes the `meta` param straight from the rule form. Rows naming no known
    # field, or left blank, are dropped the way Advanced Search drops them.
    def condition_rows=(rows)
      filters = Dam::MetadataFilter.from_params(rows, Dam::MetadataField.all.index_by(&:key))
      rows = filters.map { |filter| filter.to_h.slice(:field, :operator, :value, :value_to).stringify_keys }
      self.conditions = rows.any? ? rows.to_json : nil
    end

    # +fields+ is a key => Dam::MetadataField hash; Dam::Access passes one in
    # so a page that asks about twenty rules loads the fields once. Inactive
    # fields still count. A field that is gone, or no longer takes the stored
    # operator, is stood in for — Dam::MetadataFilter would otherwise drop
    # the row or swap in a different operator.
    def metadata_filters(fields = Dam::MetadataField.all.index_by(&:key))
      rows = condition_rows
      known = rows.to_h do |row|
        field = fields[row['field'].to_s]
        [row['field'].to_s, field&.operators&.include?(row['operator']) ? field : stand_in_field(row)]
      end
      Dam::MetadataFilter.from_params(rows, known)
    end

    def org_search
      ::FormSearch.new(filter_agency: agency_id, filter_division: division_id,
                       filter_department: department_id, filter_unit: unit_id)
    end

    # The org levels this rule narrows to, e.g. { agency: 'GSA' }.
    def org_levels
      ORG_LEVELS.index_with { |level| self[:"#{level}_id"] }.compact_blank
    end

    # Every asset this rule restricts, whether or not anyone can then see it.
    # An asset filed under no agency is outside a rule on one: it has not been
    # placed, and the rule is about what has.
    def restricted_assets(fields = Dam::MetadataField.all.index_by(&:key))
      filters = metadata_filters(fields).filter_map(&:asset_ids)
      return Dam::Asset.none if org_levels.empty? && filters.empty?

      scope = Dam::Asset.where(org_levels.transform_keys { |level| :"#{level}_id" })
      filters.reduce(scope) { |current, ids| current.where(id: ids) }
    end

    # The assets this rule opens to its grantees, or nil when it opens none.
    def granted_assets(fields = Dam::MetadataField.all.index_by(&:key))
      broken?(fields) ? nil : restricted_assets(fields)
    end

    # True when a stored condition can no longer be read as it was written.
    def broken?(fields = Dam::MetadataField.all.index_by(&:key))
      metadata_filters(fields).any? { |filter| filter.asset_ids.nil? }
    end

    def allows?(capability)
      capability = capability.to_sym
      return true if capability == :view

      CAPABILITIES.include?(capability) && self[:"can_#{capability}"]
    end

    def capability_labels
      ['View'] + CAPABILITY_LABELS.filter_map { |capability, label| label if allows?(capability) }
    end

    def covers?(access) = grantees.any? { |grantee| grantee.covers?(access) }

    # The slice of the library in words, e.g. ["Agency: General Services
    # Agency", "Usage rights equals Internal only"].
    def asset_summary(fields = Dam::MetadataField.all.index_by(&:key))
      org_search.summary + metadata_filters(fields).map(&:chip)
    end

    private

    # A field typed by the condition's own operator, so "on 2026-01-01" is
    # still read as a date after its field was deleted or turned into text.
    def stand_in_field(row)
      type = Dam::MetadataField::OPERATORS.find { |_type, operators| operators.include?(row['operator']) }&.first
      Dam::MetadataField.new(key: row['field'].to_s, label: row['field'].to_s.humanize, field_type: type || 'text')
    end

    def normalize_org_window
      ORG_LEVELS.each do |level|
        attribute = "#{level}_id"
        self[attribute] = self[attribute].to_s.strip.presence
      end
    end

    # A rule over the whole library would hide every asset from everyone
    # outside it — a lockout, not governance.
    def narrows_the_library
      return if org_levels.any? || condition_rows.any?

      errors.add(:base, 'Choose part of the organization or at least one metadata condition. ' \
                        'A rule over the whole library would hide every asset from everyone else.')
    end

    def conditions_make_sense
      metadata_filters.each do |filter|
        next unless filter.asset_ids.nil?

        errors.add(:base, "\"#{filter.chip}\" cannot be matched against #{filter.label}.")
      end
    end
  end
end
