# frozen_string_literal: true

module Aim
  # The Fiscal Dashboard (#131): one card per Fiscal list, as the pipeline's
  # dashboard has one per queue, for the agency groups picked in Managing,
  # with the latest saved reports. Counts load after the page draws
  # (aim_counts_controller), the notes with it.
  class FiscalDashboardController < BaseController
    include Aim::FiscalGroupScope

    before_action :require_fiscal

    CARDS = {
      'review' => 'aim-card-warning', 'on_hold' => 'aim-card-danger', 'ready' => 'aim-card-neutral',
      'exported' => 'aim-card-neutral', 'archived' => 'aim-card-info'
    }.freeze
    STALE_AFTER = 7.days

    def index
      reading_database('read the Fiscal dashboard', alert: 'The invoice database could not be read.',
                                                    empty: { notes: {}, reports: [] }) do
        Aim::FiscalRecord.take_in_approved!
        records = Aim::FiscalRecord.served_by(served_invoices)
        @notes = notes(records)
        @reports = latest_reports
      end
    end

    private

    def notes(records)
      review = records.in_status('review').to_a
      ready = records.in_status('ready').to_a
      {
        'review' => [("#{review.count { |r| r.invoice.manual_entry }} need data entry" if review.any? { |r| r.invoice.manual_entry }),
                     ("#{review.count { |r| r.created_at < STALE_AFTER.ago }} waiting over a week" if review.any? { |r| r.created_at < STALE_AFTER.ago })],
        'on_hold' => records.where(status: 'on_hold').group(:hold_reason).count.sort_by { |_, n| -n }.first(3)
                            .map { |reason, n| "#{n} #{reason.to_s.truncate(40)}" },
        'ready' => (["#{helpers.number_to_currency(ready.sum { |r| r.invoice.invoice_total.to_d })} in total"] if ready.any?),
        'exported' => ["#{records.where(status: 'exported').count} to archive once paid"]
      }.transform_values { |lines| Array(lines).compact.join(' · ').presence }
    end

    def latest_reports
      groups = helpers.aim_managing_groups
      scope = Aim::FiscalReport.newest_first.includes(:agency_group)
      scope = scope.where(agency_group_id: groups.map(&:id)) unless groups.nil?
      scope.limit(5).to_a
    end
  end
end
