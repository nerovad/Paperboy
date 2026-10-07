# frozen_string_literal: true

# Runs one RecordsEmailRule: finds the rows that meet its condition today and
# emails them as a CSV -- to the rule's recipients, or to each split value's
# contacts with only their rows. Nothing is sent when no row matches.
#
# The owner's edit grant is checked here, at send time, from their employee id
# (see EmployeePermissions): a rule keeps mailing a table's rows after its
# author has moved on, so losing the grant has to stop it. Such a rule is
# paused and the owner told why; an editor who still holds the grant can delete
# it and add their own.
#
# A failure is logged and not retried: a retry would mail again everyone the
# first attempt already reached.
class RecordsEmailRuleJob < ApplicationJob
  queue_as :default

  # +manual+ is the dialog's "Send now", which also runs a paused rule.
  def perform(rule_id, manual: false)
    rule = RecordsEmailRule.find_by(id: rule_id)
    return unless rule && (manual || rule.enabled?)

    owner = Submitter.resolve(rule.employee_id)
    return pause(rule, owner) unless editor?(rule)

    rows = rule.matching_rows
    return if rows.empty?

    rule.batches(rows, owner_email: owner&.email).each { |batch| deliver(rule, owner, batch) }
  rescue StandardError => e
    Rails.logger.error "Records email rule ##{rule_id} failed: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
  end

  private

  def editor?(rule)
    rule.table && EmployeePermissions.new(rule.employee_id).can_edit_record_table?(rule.table)
  end

  def pause(rule, owner)
    rule.update!(enabled: false)
    RecordsMailer.rule_paused(owner, rule).deliver_now if owner&.email.present?
  end

  # One batch failing -- a bad address, say -- does not hold up the rest.
  def deliver(rule, owner, batch)
    mail = RecordsMailer.rule_rows(rule: rule, owner: owner, batch: batch,
                                   csv: RecordsEmailSheet.new(rule.table, batch.rows).to_csv)
    mail.deliver_now

    rule.deliveries.create!(table_slug: rule.table_slug, subject: mail.subject, recipients: batch.to.join(', '),
                            row_count: batch.rows.size, group_value: batch.group,
                            sent_by_employee_id: rule.employee_id)
  rescue StandardError => e
    Rails.logger.error "Records email rule ##{rule.id} could not mail #{batch.to.join(', ')}: #{e.message}"
  end
end
