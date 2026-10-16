# frozen_string_literal: true

module Aim
  # A processed Fiscal report (#131): numbered (#000124, its id), kept with the
  # file it made and the invoices in it, so it can be downloaded again and
  # every invoice's history names it. Processing moves the Report Queue's
  # invoices to Exported. The file is purged a year on; the row, its invoice
  # list and the history lines stay.
  class FiscalReport < Record
    KEEP_FOR = 1.year

    belongs_to :agency_group, class_name: 'Aim::AgencyGroup', optional: true
    belongs_to :report_template, class_name: 'Aim::ReportTemplate', optional: true
    belongs_to :replaces, class_name: 'Aim::FiscalReport', foreign_key: :replaces_report_id, optional: true
    has_many :report_invoices, class_name: 'Aim::FiscalReportInvoice', dependent: :delete_all
    has_many :invoices, through: :report_invoices

    scope :newest_first, -> { order(id: :desc) }
    scope :expired, -> { where(purged_at: nil).where(expires_at: ..Time.current) }

    def self.number_for(id) = format('#%06d', id)

    # Saves the report +export+ (an Aim::FiscalExport) made, numbered, links
    # its invoices, writes each one's history line, and moves the Report
    # Queue's to Exported. +layout+ is the group or template it was laid out
    # by; +replaces+ the report it regenerates.
    def self.process!(export, layout:, by:, replaces: nil)
      transaction do
        report = create!(layout_attributes(layout).merge(export_format: export.tab? ? 'tab' : 'csv', file_name: export.filename,
                                                         content: export.body.b, invoice_count: export.records.size,
                                                         replaces: replaces, created_by: by, expires_at: KEEP_FOR.from_now))
        report.update!(file_name: export.filename(report.id))
        export.records.each { |record| report.take_in!(record, by: by) }
        report
      end
    end

    def self.layout_attributes(layout)
      case layout
      when Aim::ReportTemplate then { agency_group: layout.agency_group, report_template: layout, layout_name: "#{layout.agency_group.name}: #{layout.name}" }
      when Aim::AgencyGroup then { agency_group: layout, layout_name: "#{layout.name}: Default" }
      else { layout_name: 'AIM report' }
      end
    end

    def number = self.class.number_for(id)

    def purged? = purged_at.present?

    def content_type = export_format == 'tab' ? 'text/tab-separated-values' : 'text/csv'

    # The layout to lay a regenerated copy out by: the template still saved,
    # else the group's Default.
    def layout = report_template || agency_group

    def take_in!(record, by:)
      report_invoices.create!(invoice_id: record.invoice_id)
      note = "In Fiscal report #{number} (#{layout_name})#{", replacing #{replaces.number}" if replaces}"
      if record.status == 'ready'
        record.move_to!('exported', actor: by, note: note, exported_at: Time.current)
      else
        record.invoice.events.create!(action: 'fiscal', actor: by, note: note)
      end
    end

    def purge!
      update!(content: nil, purged_at: Time.current)
    end
  end
end
