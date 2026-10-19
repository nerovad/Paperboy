# frozen_string_literal: true

module Aim
  # AIM's email alerts (#131): who would be told what, by the settings of each
  # invoice's agency group and budget unit (Aim::AlertSetting). Nothing is sent
  # unless AIM_EMAIL_ALERTS=on; until then the Alerts tab previews it.
  #
  #   Aim::Alerts.digests  # => { employee_id => { 'owner_past_due' => [invoice, ...], ... } }
  class Alerts
    DAY = 1.day

    def self.enabled? = ENV.fetch('AIM_EMAIL_ALERTS', '').casecmp?('on')

    def self.from = ENV['AIM_ALERT_FROM'].presence

    # The high-dollar invoice has reached its second approver: told at once.
    def self.second_approval_reached(invoice)
      return unless enabled?

      group = Aim::AgencyGroups.new.for_invoice(invoice)
      return unless Aim::AlertSetting.effective(group, invoice.budget_unit).dig('second_approval', :on)

      Aim::AlertMailer.second_approval(invoice.id).deliver_later
    end

    def initialize(now: Time.current, groups: Aim::AgencyGroups.new)
      @now = now
      @groups = groups
      @settings = {}
    end

    # The daily digest, for everyone it has something for. +only+ limits it to
    # some agency groups (the Alerts tab's preview).
    def digests(only: nil)
      out = Hash.new { |hash, id| hash[id] = Hash.new { |kinds, kind| kinds[kind] = [] } }
      owned.each { |invoice, waited| owner_alerts(out, invoice, waited) if wanted?(invoice, only) }
      shared.each { |invoice, waited| admin_alert(out, invoice, 'bu_admin_shared_past_due', waited) if wanted?(invoice, only) }
      duplicates.each { |invoice| admin_alert(out, invoice, 'bu_admin_duplicates') if wanted?(invoice, only) }
      out
    end

    private

    def wanted?(invoice, only) = only.nil? || only.map(&:id).include?(@groups.for_invoice(invoice)&.id)

    def setting(invoice, kind)
      group = @groups.for_invoice(invoice)
      @settings[[group&.id, invoice.budget_unit]] ||= Aim::AlertSetting.effective(group, invoice.budget_unit)
      @settings[[group&.id, invoice.budget_unit]][kind]
    end

    def owner_alerts(out, invoice, waited)
      past = setting(invoice, 'owner_past_due')
      out[invoice.assigned_employee_id]['owner_past_due'] << invoice if past[:on] && waited >= past[:days] * DAY
      out[invoice.assigned_employee_id]['owner_new'] << invoice if setting(invoice, 'owner_new')[:on] && waited < DAY
    end

    def admin_alert(out, invoice, kind, waited = nil)
      rule = setting(invoice, kind)
      return unless rule[:on] && (waited.nil? || waited >= rule[:days] * DAY)

      bu_admins[invoice.budget_unit].each { |id| out[id][kind] << invoice }
    end

    def ready = Aim::Invoice.in_queue('ready_for_approval')

    # [[invoice, how long it has been where it is], ...]
    def owned = with_wait(ready.where.not(assigned_employee_id: nil).to_a)
    def shared = with_wait(ready.where(assigned_employee_id: nil).to_a)

    def duplicates = Aim::Invoice.where(state: 'needs_review', review_reason: 'duplicate').to_a

    # Since it last reached Ready for Approval or changed hands.
    def with_wait(invoices)
      since = Aim::InvoiceEvent.where(invoice_id: invoices.map(&:id))
                               .where("to_state = 'ready_for_approval' OR action = 'assignment'")
                               .group(:invoice_id).maximum(:created_at)
      invoices.map { |invoice| [invoice, @now - (since[invoice.id] || invoice.created_at)] }
    end

    def bu_admins
      @bu_admins ||= Aim::UserBudgetUnit.administered.pluck(:budget_unit, :employee_id)
                                        .group_by(&:first).transform_values { |pairs| pairs.map(&:last).uniq }
                                        .tap { |hash| hash.default = [] }
    end
  end
end
