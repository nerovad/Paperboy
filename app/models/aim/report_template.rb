# frozen_string_literal: true

module Aim
  # A Fiscal report template (#131): a named layout an agency group saves
  # and picks from when downloading, beside the group's own Default.
  class ReportTemplate < Record
    include Aim::ReportLayout

    belongs_to :agency_group, class_name: 'Aim::AgencyGroup', inverse_of: :report_templates

    before_validation { self.name = name.to_s.squish }

    validates :name, presence: true, length: { maximum: 100 }, uniqueness: { scope: :agency_group_id }

    scope :by_name, -> { order(:name) }
  end
end
