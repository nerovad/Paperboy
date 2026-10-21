# frozen_string_literal: true

# A named Bates counter (#230): the next number to give, zero-padded to
# +digits+ (set by its zeros: "000123"), and how its stamp looks (stamp
# areas, as Paperboy::Pdf::StampAreas reads them, and an optional page
# shrink). A prefix is plain text in a stamp row: "GSA-{number}".
#
# Numbers are only taken by #run!, which locks the row, stamps, and moves the
# counter on in one transaction, so two people stamping at once never get the
# same numbers. Every run is a BatesRun row.
class BatesCounter < ApplicationRecord
  SHRINKS = [100, 95, 90, 85, 80, 75, 70].freeze
  MAX_AREAS = 10
  MAX_FILES = 50
  # A new counter's stamp: its number, bottom right of every page.
  DEFAULT_AREAS = [
    Paperboy::Pdf::StampBox::DEFAULTS.except(:lines).merge(
      name: 'Bates number', rows: ['{number}'], x: 18.0, y: 14.0, size: 10.0, font: 'courier', bold: true, leading: 1.2
    )
  ].freeze
  # The fields a Bates stamp can use, with samples for the designer.
  FIELDS = {
    'number' => { label: 'Running number', group: 'Numbering' },
    'page' => { label: 'Page of the file', group: 'Numbering' },
    'pages' => { label: 'Pages in the file', group: 'Numbering' },
    'stamped_on' => { label: 'Date stamped', group: 'Other', format: '%m/%d/%Y' }
  }.freeze

  has_many :runs, -> { order(id: :desc) }, class_name: 'BatesRun', inverse_of: :counter, dependent: :restrict_with_exception

  validates :name, presence: true, length: { maximum: 100 }, uniqueness: { case_sensitive: false }
  validates :digits, inclusion: { in: 1..12 }
  validates :next_number, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :page_shrink, inclusion: { in: SHRINKS }, allow_nil: true
  validates :page_position, inclusion: { in: Paperboy::Pdf::Geometry::POSITIONS }, allow_nil: true
  validates :created_by, presence: true
  validate :areas_make_sense

  scope :by_name, -> { order(:name) }

  def area_list
    list = JSON.parse(areas.presence || DEFAULT_AREAS.to_json)
    list.is_a?(Array) ? list.grep(Hash) : []
  rescue JSON::ParserError
    []
  end

  def area_list=(list)
    self.areas = Array(list).map { |area| area.to_h.stringify_keys }.to_json
  end

  def bates(start = next_number) = Paperboy::Pdf::Bates.build(prefix: '', digits: digits, start: start)

  # The next number as it is written, with its zeros: "000123".
  def start_text = bates.label(next_number)

  # Takes "000123": six digits, next number 123.
  def start_text=(text)
    parsed = Paperboy::Pdf::Bates.from_start(text)
    self.digits = parsed.digits
    self.next_number = parsed.start
  end

  def shrink
    return if page_shrink.nil? || page_shrink >= 100

    { scale: page_shrink / 100.0, position: page_position.presence || 'center' }
  end

  def values = { 'stamped_on' => Time.zone.today }

  def formats = FIELDS.transform_values { |field| field[:format] }.compact

  # The PDFs at +paths+ (named +names+) stamped from this counter's next
  # number, without taking any numbers: a check.
  def preview(paths) = Paperboy::Pdf::BatesRun.new(bates, area_list, values: values, shrink: shrink).stamp(paths)

  # Stamps the PDFs and takes their numbers: the counter moves on and the run
  # is logged, in one locked transaction. Returns [result, run].
  def run!(paths, names:, by:)
    with_lock do
      result = Paperboy::Pdf::BatesRun.new(bates, area_list, values: values, shrink: shrink).stamp(paths)
      run = runs.create!(digits: digits, first_number: result.first_number, last_number: result.last_number,
                         page_count: result.pages, file_names: names.join("\n"), created_by: by)
      update!(next_number: result.last_number + 1, updated_by: by)
      [result, run]
    end
  end

  private

  def areas_make_sense
    list = area_list
    return errors.add(:base, 'A stamp needs at least one area.') if list.empty?
    return errors.add(:base, "A stamp can have at most #{MAX_AREAS} areas.") if list.size > MAX_AREAS

    unknown = list.flat_map { |area| Array(area['rows']).flat_map { |row| Paperboy::Pdf::StampTemplate.fields(row) } }.uniq - FIELDS.keys
    errors.add(:base, "Unknown fields: #{unknown.join(', ')}.") if unknown.any?
  end
end
