# frozen_string_literal: true

module Aim
  # One version of an invoice's PDF (#182): the base PDF it starts from and
  # any inserted PDFs (file names in the invoice's store folder), and the
  # editor's plan for them -- pages, turns, crops, text boxes -- or none for
  # the base as it is. Written once; a restore is a new version.
  class PdfVersion < Record
    KINDS = %w[received swap edit restore].freeze

    belongs_to :invoice, class_name: 'Aim::Invoice'

    validates :number, :kind, :base_file, :created_by, presence: true
    validates :kind, inclusion: { in: KINDS }
    validates :number, uniqueness: { scope: :invoice_id }

    scope :newest_first, -> { order(number: :desc) }

    def plan_pages = plan.present? ? JSON.parse(plan) : nil

    def insert_files = inserts.present? ? JSON.parse(inserts) : []

    def base_path = File.join(invoice.store_dir, base_file)

    def insert_paths = insert_files.map { |name| File.join(invoice.store_dir, name) }
  end
end
