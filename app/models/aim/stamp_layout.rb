# frozen_string_literal: true

module Aim
  # What an agency group's approval stamp says and where (#221): one or more
  # stamp areas, all written in the one stamping when an invoice is approved.
  # Each area is a Paperboy::Pdf::StampBox's settings plus its rows of text,
  # with fields from Aim::StampFields ("{approver}_{approved_at}").
  #
  # Every save is a new row (append-only), so the rows are the history; the
  # newest for a group is its layout, the newest with no group is the default
  # for groups with none, and BUILT_IN -- the stamp AIM has always written --
  # stands when nobody has saved one.
  class StampLayout < Record
    include Aim::AppendOnly

    MAX_AREAS = 10
    MAX_ROWS = 12
    MAX_ROW_LENGTH = 300

    # The approval stamp as it was before layouts: bottom right of every
    # page, 7pt Helvetica right-aligned over a white box.
    BUILT_IN = [
      Paperboy::Pdf::StampBox::DEFAULTS.except(:lines).merge(
        name: 'Approval',
        rows: ['{received}- Invoice Date:{invoice_date|%Y%m%d}',
               '1st: {first_approver}_{first_approved_at}',
               '{approver}_{approved_at}']
      )
    ].freeze

    belongs_to :agency_group, class_name: 'Aim::AgencyGroup', optional: true

    validates :created_by, presence: true
    validate :areas_make_sense

    scope :history_for, ->(group) { where(agency_group_id: group&.id).order(id: :desc) }

    # The layout an invoice in +group+ is stamped with: the group's own, else
    # the default, else BUILT_IN (unsaved).
    def self.current_for(group)
      (group && history_for(group).first) || history_for(nil).first || built_in
    end

    def self.built_in = new(areas: BUILT_IN.to_json, created_by: 'aim')

    # The areas as hashes: { 'name', 'rows', and StampBox's settings }.
    def area_list
      list = JSON.parse(areas.presence || '[]')
      list.is_a?(Array) ? list.grep(Hash) : []
    rescue JSON::ParserError
      []
    end

    def area_list=(list)
      self.areas = Array(list).map { |area| area.to_h.stringify_keys }.to_json
    end

    def built_in? = new_record? && created_by == 'aim'

    # The stamp areas filled for one invoice's +values+ (Aim::StampFields),
    # with rows whose fields are all empty left out, and areas left with no
    # rows dropped.
    def boxes(values)
      template = Paperboy::Pdf::StampTemplate.new(values, formats: Aim::StampFields.formats)
      area_list.filter_map do |area|
        lines = template.lines(Array(area['rows']))
        Paperboy::Pdf::StampBox.build(area.except('name', 'rows').merge('lines' => lines)) if lines.any?
      end
    end

    private

    def areas_make_sense
      list = area_list
      return errors.add(:areas, 'need at least one stamp area') if list.empty?
      return errors.add(:areas, "can be at most #{MAX_AREAS}") if list.size > MAX_AREAS

      list.each_with_index { |area, index| check_area(area, index + 1) }
    end

    def check_area(area, number)
      rows = Array(area['rows'])
      errors.add(:areas, "area #{number} needs at least one row of text") if rows.none?(&:present?)
      errors.add(:areas, "area #{number} can have at most #{MAX_ROWS} rows") if rows.size > MAX_ROWS
      rows.each do |row|
        errors.add(:areas, "area #{number} has a row over #{MAX_ROW_LENGTH} characters") if row.to_s.length > MAX_ROW_LENGTH
        unknown = Paperboy::Pdf::StampTemplate.fields(row).reject { |name| Aim::StampFields.known?(name) }
        errors.add(:areas, "area #{number} names unknown fields: #{unknown.uniq.join(', ')}") if unknown.any?
      end
    end
  end
end
