# frozen_string_literal: true

module Aim
  # A reason offered when an invoice is rejected (#131): everywhere when it has
  # no agency group (AIM Admins keep those), or for one group's invoices (its
  # Group Admins keep them). "Other" with a typed reason is always offered too.
  class RejectReason < Record
    OTHER = 'other'

    belongs_to :agency_group, class_name: 'Aim::AgencyGroup', optional: true

    before_validation { self.label = label.to_s.squish }

    validates :label, presence: true, length: { maximum: 200 }

    scope :ordered, -> { order(:position, :id) }
    scope :global, -> { where(agency_group_id: nil) }

    # The reasons offered for an invoice of +group+: everyone's, then the
    # group's own, without repeats.
    def self.offered_for(group)
      (global.ordered.pluck(:label) + (group ? where(agency_group_id: group.id).ordered.pluck(:label) : [])).uniq
    end

    # Replaces one list (nil: everyone's) with +text+, one reason per line.
    def self.replace!(group, text, by:)
      labels = text.to_s.lines.map(&:squish).compact_blank.uniq
      transaction do
        where(agency_group_id: group&.id).delete_all
        labels.each_with_index { |label, index| create!(agency_group: group, label: label, position: index, updated_by: by) }
      end
    end

    def self.text_for(group) = where(agency_group_id: group&.id).ordered.pluck(:label).join("\n")
  end
end
