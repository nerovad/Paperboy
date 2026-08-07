# frozen_string_literal: true

module Dam
  # A registered piece of work the DAM can run over assets.
  #
  # Workflows are not all Ruby — AI metadata extraction is Python, engine and
  # transcode work is C++ — so the runtime is stored rather than assumed, and
  # the runner picks an invocation from it. Adding a language later is a new
  # RUNTIMES entry, not a new model.
  class Workflow < ApplicationRecord
    RUNTIMES = {
      'ruby' => 'Ruby',
      'python' => 'Python',
      'cpp' => 'C++',
      'shell' => 'Shell'
    }.freeze

    TRIGGERS = {
      'manual' => 'Run by hand',
      'on_ingest' => 'Automatically, when an asset is ingested',
      'scheduled' => 'On a schedule'
    }.freeze

    has_many :jobs, class_name: 'Dam::Job', dependent: :nullify,
                    foreign_key: :workflow_id, inverse_of: :workflow

    validates :name, presence: true
    validates :slug, presence: true, uniqueness: { case_sensitive: false }
    validates :runtime, inclusion: { in: RUNTIMES.keys }
    validates :trigger, inclusion: { in: TRIGGERS.keys }
    validates :schedule, presence: true, if: -> { trigger == 'scheduled' }

    before_validation :derive_slug, on: :create

    scope :enabled, -> { where(enabled: true) }
    scope :alphabetical, -> { order(:name) }

    def to_s = name

    def runtime_label = RUNTIMES.fetch(runtime, runtime)

    def trigger_label = TRIGGERS.fetch(trigger, trigger)

    # Media types this workflow will act on; empty means anything. Stored as a
    # comma list so the edit form can be a plain multi-select.
    def media_type_list
      applies_to_media_types.to_s.split(',').map(&:strip).reject(&:blank?)
    end

    def media_type_list=(values)
      self.applies_to_media_types = Array(values).reject(&:blank?).join(',')
    end

    def applies_to?(asset)
      list = media_type_list
      list.empty? || list.include?(asset.media_type)
    end

    def last_job = jobs.order(created_at: :desc).first

    private

    def derive_slug
      self.slug = name.to_s.parameterize(separator: '_') if slug.blank?
    end
  end
end
