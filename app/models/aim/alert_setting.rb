# frozen_string_literal: true

module Aim
  # One kind of email alert, on or off, for an agency group (budget_unit
  # blank) or one of its budget units, which then overrides the group (#131).
  # Kinds and their defaults are in KINDS; a group with no row has the
  # defaults. Nothing is sent unless AIM_EMAIL_ALERTS=on (Aim::Alerts).
  class AlertSetting < Record
    KINDS = {
      'owner_past_due' => { who: 'Owners', what: 'invoices in their queue longer than', on: true, days: 7 },
      'owner_new' => { who: 'Owners', what: 'new invoices in their queue', on: false },
      'bu_admin_duplicates' => { who: 'BU Admins', what: 'possible duplicates in their BUs', on: true },
      'bu_admin_shared_past_due' => { who: 'BU Admins', what: 'unowned shared-queue invoices older than', on: true, days: 7 },
      'second_approval' => { who: 'Second approvers', what: 'a high-dollar invoice reaching them', on: true }
    }.freeze

    belongs_to :agency_group, class_name: 'Aim::AgencyGroup'

    validates :kind, inclusion: { in: KINDS.keys }
    validates :kind, uniqueness: { scope: %i[agency_group_id budget_unit] }
    validates :days, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true

    # { kind => { on:, days: } } for +group+, and +unit+ when given: the
    # unit's own rows, else the group's, else the defaults.
    def self.effective(group, unit = nil)
      rows = group ? where(agency_group_id: group.id, budget_unit: [nil, unit].uniq).to_a : []
      KINDS.to_h do |kind, default|
        row = rows.find { |r| r.kind == kind && unit && r.budget_unit == unit } ||
              rows.find { |r| r.kind == kind && r.budget_unit.nil? }
        [kind, { on: row ? row.enabled : default[:on], days: row&.days || default[:days] }]
      end
    end

    # Replaces a group's (unit nil) or a unit's settings: { kind => { on:, days: } }.
    def self.replace!(group, unit, settings, by:)
      transaction do
        where(agency_group_id: group.id, budget_unit: unit).delete_all
        settings.each do |kind, values|
          next unless KINDS.key?(kind)

          create!(agency_group: group, budget_unit: unit, kind: kind, enabled: values[:on],
                  days: (values[:days] if KINDS[kind][:days]), updated_by: by)
        end
      end
    end

    def self.overridden_units(group) = where(agency_group_id: group.id).where.not(budget_unit: nil).distinct.pluck(:budget_unit)
  end
end
