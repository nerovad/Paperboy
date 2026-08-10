# frozen_string_literal: true

module Dam
  # One run of anything the DAM does in the background: an ingest, an export, a
  # share delivery, or a custom workflow.
  #
  # One table for all four because the Jobs screen is a single status feed and
  # every kind needs the same facts — state, counts, timings, error, who asked.
  class Job < ApplicationRecord
    JOB_TYPES = {
      'ingest' => 'Ingest',
      'export' => 'Export',
      'share' => 'Share',
      'move' => 'Move',
      'workflow' => 'Workflow'
    }.freeze

    STATUSES = %w[queued running succeeded failed cancelled].freeze
    OPEN_STATUSES = %w[queued running].freeze

    belongs_to :workflow, class_name: 'Dam::Workflow', optional: true
    belongs_to :subject, polymorphic: true, optional: true

    validates :job_type, inclusion: { in: JOB_TYPES.keys }
    validates :status, inclusion: { in: STATUSES }

    scope :newest_first, -> { order(created_at: :desc) }
    scope :open, -> { where(status: OPEN_STATUSES) }
    scope :finished, -> { where.not(status: OPEN_STATUSES) }
    scope :of_type, ->(type) { where(job_type: type) }

    def type_label = JOB_TYPES.fetch(job_type, job_type.to_s.titleize)

    def open? = OPEN_STATUSES.include?(status)

    def failed? = status == 'failed'

    # 0-100. Falls back to the terminal state when no item counts were set, so
    # a job that never reported progress still draws a full or empty bar rather
    # than a stuck one.
    def percent_complete
      return 100 if %w[succeeded cancelled].include?(status)
      return 0 if total_items.to_i.zero?

      [(processed_items.to_f / total_items * 100).round, 100].min
    end

    def duration
      return nil if started_at.blank?

      ((finished_at || Time.current) - started_at).round
    end

    # Raise a queued job. The runner picks these up; nothing here executes.
    def self.enqueue!(job_type:, actor: nil, workflow: nil, subject: nil, total_items: 0)
      create!(
        job_type: job_type,
        workflow: workflow,
        subject: subject,
        # Asset carries a title, Collection a name, StorageLocation a label.
        # Never #to_s — on an unadorned model that is the inspect string.
        subject_label: subject.try(:title) || subject.try(:name) || subject.try(:label),
        status: 'queued',
        total_items: total_items,
        queued_at: Time.current,
        created_by_id: actor&.employee_id&.to_s,
        created_by_name: actor && "#{actor.first_name} #{actor.last_name}".strip
      )
    end

    # Record something that has already happened. An ingest and a storage move
    # both finish inside the request, so they never pass through the runner —
    # the row lands complete, and the Jobs feed stays the one place every piece
    # of DAM work shows up whether or not it was ever queued.
    def self.record!(job_type:, actor:, subject:, count: 1, log: nil)
      job = enqueue!(job_type: job_type, actor: actor, subject: subject, total_items: count)
      Array(log).each { |line| job.append_log(line) }
      job.update!(status: 'succeeded', processed_items: count, started_at: Time.current,
                  finished_at: Time.current, log: job.log)
      job
    end

    # Append one line to the run log. Kept as text rather than rows because
    # nothing queries inside a log — it is read whole, on the job's own page.
    def append_log(line)
      self.log = [log, "[#{Time.current.strftime('%H:%M:%S')}] #{line}"].compact_blank.join("\n")
    end
  end
end
