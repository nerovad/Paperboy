# frozen_string_literal: true

# OSHA-reportable incidents must have their 301 filed within 8 hours. Stamp the
# deadline on the report when it is spawned from a reportable safety report so
# the sweep can query for breaches instead of recomputing them, and record when
# the single breach notice went out so it can't be sent twice.
class AddReportableDeadlineToOshaReports < ActiveRecord::Migration[8.0]
  def change
    add_column :osha_reports, :reportable_due_at, :datetime
    add_column :osha_reports, :reportable_breach_notified_at, :datetime

    add_index :osha_reports, %i[reportable_due_at reportable_breach_notified_at],
              name: 'index_osha_reports_on_reportable_deadline'
  end
end
