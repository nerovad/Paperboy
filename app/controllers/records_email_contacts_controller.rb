# frozen_string_literal: true

# The contacts a Records table's email rules send each column value's rows to
# -- Agency "GSA" goes to these people -- typed in by the table's editors from
# the grid's Email dialog. See RecordsEmailContact.
class RecordsEmailContactsController < ApplicationController
  include RecordsEmailDialog

  # Several addresses may be added to one value at once.
  def create
    emails = RecordsEmailRecipients.parse(params.dig(:contact, :emails))
    return redirect_to(back_to_grid, alert: 'Enter at least one email address.') if emails.empty?

    contacts = emails.map do |email|
      RecordsEmailContact.new(contact_params.merge(table_slug: @table.slug, email: email,
                                                   created_by_employee_id: current_employee_id))
    end
    saved, failed = contacts.partition(&:save)

    redirect_to back_to_grid, **outcome(saved, failed)
  end

  def destroy
    RecordsEmailContact.for_table(@table.slug).find_by(id: params[:id])&.destroy
    redirect_to back_to_grid, notice: 'Contact removed.'
  end

  private

  def contact_params
    params.require(:contact).permit(:column_name, :match_value)
  end

  def outcome(saved, failed)
    problems = failed.flat_map { |contact| contact.errors.full_messages }.uniq.join(', ')
    return { alert: "Could not add contact: #{problems}" } if saved.empty?

    added = "Added #{saved.map(&:email).join(', ')} for #{saved.first.match_value}."
    failed.empty? ? { notice: added } : { notice: added, alert: "Not added: #{problems}" }
  end
end
