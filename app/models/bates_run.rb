# frozen_string_literal: true

# One Bates stamping (#230): the counter, the numbers it took (first to
# last), the pages, the files' names and who ran it. Written once, never
# changed. The files themselves are not kept.
class BatesRun < ApplicationRecord
  belongs_to :counter, class_name: 'BatesCounter', foreign_key: :bates_counter_id, inverse_of: :runs

  validates :first_number, :last_number, :page_count, :created_by, presence: true

  def readonly? = persisted? || super

  # The numbers as they were stamped, padded to the digits of the time.
  def range
    bates = Paperboy::Pdf::Bates.build(prefix: '', digits: digits, start: first_number)
    "#{bates.label(first_number)} - #{bates.label(last_number)}"
  end

  def file_list = file_names.to_s.split("\n")
end
