# frozen_string_literal: true

module Dam
  # Files an asset under an agency / division / department / unit from the
  # free-text org metadata ResourceSpace sent (`agency`, `division`,
  # `department`, `unit`; see ResourceSpace::FieldMap).
  #
  # Access rules key on the org columns, not on that text, so an imported
  # asset has to be placed before a rule on its agency can see it. The text
  # is whatever ResourceSpace held — an id ("GSA"), a name ("General Services
  # Agency"), either case — so each level is matched on id or long name,
  # within the level above it. A level that matches nothing stops the walk:
  # an asset filed under the wrong department is worse than one filed only
  # under its agency.
  #
  # Only fills columns left blank, so nothing someone set by hand is undone.
  class OrgFromMetadata
    KEYS = { agency: 'agency', division: 'division', department: 'department', unit: 'unit' }.freeze

    def self.apply(asset) = new(asset).apply

    # Every asset not yet filed anywhere, for `rake dam:file_assets_by_org`.
    # Returns [how many were filed, { agency text => assets it failed to place }].
    def self.file_all(dry_run: false)
      filed = 0
      unmatched = Hash.new(0)
      Dam::Asset.where(agency_id: nil).includes(:metadata_values).find_each do |asset|
        if apply(asset)
          filed += 1
          asset.save! unless dry_run
        elsif (text = new(asset).text_for(:agency)).present?
          unmatched[text] += 1
        end
      end
      [filed, unmatched]
    end

    def initialize(asset)
      @asset = asset
      @text = asset.metadata_values.to_h { |value| [value.field_key, value.value.to_s.strip] }
    end

    # Returns true when it changed anything. Best-effort: the org tables live
    # on GSABSS, and an import must not fail because they are unreachable.
    def apply
      return false if @asset.agency_id.present?

      agency = match(Coa::Agency.all, :agency_id, @text[KEYS[:agency]])
      return false if agency.nil?

      @asset.agency_id = agency
      division = match(Coa::Division.where(agency_id: agency), :division_id, @text[KEYS[:division]])
      @asset.division_id = division
      department = division && match(Coa::Department.where(division_id: division), :department_id,
                                     @text[KEYS[:department]])
      @asset.department_id = department
      @asset.unit_id = department && match(Coa::Unit.where(department_id: department), :unit_id, @text[KEYS[:unit]])
      true
    rescue StandardError => e
      Rails.logger.warn("[Dam::OrgFromMetadata] asset #{@asset.id}: #{e.class}: #{e.message}")
      false
    end

    def text_for(level) = @text[KEYS.fetch(level)]

    private

    def match(scope, id_column, text)
      return nil if text.blank?

      id = id_column == :agency_id ? Coa::Agency.normalize_id(text) : text
      scope.where(id_column => id).or(scope.where(long_name: text)).pick(id_column)
    end
  end
end
