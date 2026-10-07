# frozen_string_literal: true

# Emails sent from a Records grid's Email dialog: a view someone chose to send
# now, and the rows a RecordsEmailRule caught. Both carry the rows as a CSV
# and reply to the person who sent or set them up, not to the app.
class RecordsMailer < ApplicationMailer
  # How many rows are named in the body before it defers to the attachment.
  LISTED_ROWS = 25

  # One batch of a rule's run (see RecordsEmailRule::Batch).
  def rule_rows(rule:, owner:, batch:, csv:)
    @rule = rule
    @table = rule.table
    @batch = batch
    @owner = owner
    @row_labels = batch.rows.first(LISTED_ROWS).map { |row| @table.row_label(row) }
    @filename = RecordsCsv.filename(@table)

    attachments[@filename] = { mime_type: 'text/csv', content: csv }

    mail(
      to: batch.to,
      reply_to: owner&.email.presence,
      subject: "#{@table.label}: #{rule.label} (#{batch.rows.size})"
    )
  end

  # The view on someone's grid, sent by them to other employees.
  def view_rows(table:, sender:, to:, csv:, row_count:, note:, view_description:)
    @table = table
    @sender = sender
    @row_count = row_count
    @note = note
    @view_description = view_description
    @filename = RecordsCsv.filename(table)

    attachments[@filename] = { mime_type: 'text/csv', content: csv }

    mail(
      to: to,
      reply_to: sender['email'].presence,
      subject: "#{table.label} (#{row_count} #{'row'.pluralize(row_count)})"
    )
  end

  # The rule's owner can no longer edit its table, so it was paused.
  def rule_paused(owner, rule)
    @owner = owner
    @rule = rule

    mail(
      to: owner.email,
      subject: "Email rule paused - #{rule.table&.label || rule.table_slug}"
    )
  end
end
