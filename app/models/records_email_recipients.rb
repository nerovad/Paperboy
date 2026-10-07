# frozen_string_literal: true

# Who a Records email may go to: county employees, by the address on their
# Employees row. A Records table is gated by the ACL, and an email is a copy of
# it nobody can take back, so an address typed into the grid's Email dialog is
# checked when it is saved and again every time something is sent -- someone
# who has left the county since stops receiving.
module RecordsEmailRecipients
  module_function

  # "a@x.org, b@x.org; c@x.org" or one per line -> a list of addresses.
  def parse(text)
    normalize(text.to_s.split(/[\s,;]+/))
  end

  def normalize(emails)
    Array(emails).map { |email| email.to_s.strip.downcase }.compact_blank.uniq
  end

  # The addresses that belong to an employee, in the order given.
  def county(emails)
    emails = normalize(emails)
    return [] if emails.empty?

    known = Employee.where(email: emails).pluck(:email).to_set { |email| email.to_s.strip.downcase }
    emails.select { |email| known.include?(email) }
  end

  def outsiders(emails)
    normalize(emails) - county(emails)
  end
end
