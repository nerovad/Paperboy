# frozen_string_literal: true

module Aim
  # Reads the queue folders on the share and makes the aim.invoices rows say
  # the same thing.
  #
  # Until the workers write their own rows (step 5.6), the folders are still
  # the truth and this is what gives the database anything to read. It is also
  # what the go-live cutover uses: the rows can be rebuilt from the share at
  # any time, so a lost or stale database is never a lost invoice.
  #
  # Three things can be found, and they are not the same thing:
  #
  # * a folder with no row      -- adopted, at whatever queue it sits in;
  # * a folder whose row moved  -- a move the pipeline makes, recorded as the
  #                                transition it is;
  # * a folder that jumped      -- a move the pipeline does not make, because
  #                                someone dragged it. Recorded as a `sync`
  #                                event saying so, rather than pretended to be
  #                                an ordinary transition or silently refused.
  #
  # A row whose folder has gone is only counted. The worker may be part way
  # through moving it, and this class never decides an invoice has ended.
  class QueueSync
    ACTOR = 'queue_sync'

    # Every state that is a folder on the share. `archived` and `deleted` are
    # deliberately absent: those folders hold finished work in their own layout
    # and are not a queue to be read back.
    SYNCED_STATES = (Aim::Invoice::STATES - %w[archived deleted]).freeze

    # Queues whose invoices sit one level down. Rails files a rejected invoice
    # under <Submitter>_<BU>/<batch_id>, so the first level there is a group,
    # not an invoice; reading it as one adopted "Jane Doe_4601" as a batch.
    NESTED_STATES = %w[rejected].freeze

    Report = Struct.new(:adopted, :moved, :jumped, :missing, :folder_counts, :row_counts, :unavailable,
                        keyword_init: true) do
      def changed = adopted + moved + jumped

      # True when every queue read from the share has as many rows as folders.
      # A state with no folders and no rows agrees at zero, so compare values
      # rather than the hashes: row_counts simply has no key for an empty one.
      def agreed?
        folder_counts.all? { |state, folders| row_counts.fetch(state, 0) == folders }
      end

      # The queues where the two disagree, and by how much, for the screen
      # that reports the dual run.
      def disagreements
        folder_counts.filter_map do |state, folders|
          rows = row_counts.fetch(state, 0)
          [state, { folders: folders, rows: rows }] unless rows == folders
        end.to_h
      end
    end

    def initialize(directory_service: Aim::InvoiceDirectoryService.instance, actor: ACTOR)
      @directory_service = directory_service
      @actor = actor
    end

    def call
      report = Report.new(adopted: 0, moved: 0, jumped: 0, missing: 0,
                          folder_counts: {}, row_counts: {}, unavailable: [])

      SYNCED_STATES.each { |state| sync_state(state, report) }
      # No queue reachable means AIM is not set up on this host -- a teammate's
      # machine, a server AIM does not run on. Touch nothing, not even the
      # database, which may not have the aim schema at all.
      return report if report.folder_counts.empty?

      report.missing = missing_folders(report)
      report.row_counts = Aim::Invoice.group(:state).count.symbolize_keys

      report
    end

    private

    attr_reader :directory_service, :actor

    def sync_state(state, report)
      path = directory_service.path_for(state)
      if path.blank? || !Dir.exist?(path)
        report.unavailable << state.to_sym
        return
      end

      batch_ids = NESTED_STATES.include?(state) ? nested_folder_names(path) : folder_names(path)
      report.folder_counts[state.to_sym] = batch_ids.length
      batch_ids.each { |batch_id| sync_folder(batch_id, state, report) }
    end

    def folder_names(path)
      Dir.children(path).select { |name| File.directory?(File.join(path, name)) }
    rescue SystemCallError => e
      Rails.logger.warn("AIM queue sync could not read #{path}: #{e.message}")
      []
    end

    def nested_folder_names(path)
      folder_names(path).flat_map { |group| folder_names(File.join(path, group)) }
    end

    def sync_folder(batch_id, state, report)
      invoice = Aim::Invoice.find_by(batch_id: batch_id)
      return adopt(batch_id, state, report) if invoice.nil?
      return if invoice.state == state

      legal = invoice.next_states.include?(state)
      invoice.record_move!(state, actor: actor, note: legal ? 'seen in this queue on the share' : nil)
      legal ? report.moved += 1 : report.jumped += 1
    end

    def adopt(batch_id, state, report)
      Aim::Invoice.create!(batch_id: batch_id, state: state, actor: actor)
      report.adopted += 1
    end

    def missing_folders(report)
      seen = report.folder_counts.keys
      return 0 if seen.empty?

      Aim::Invoice.where(state: seen.map(&:to_s)).count - report.folder_counts.values.sum
    end
  end
end
