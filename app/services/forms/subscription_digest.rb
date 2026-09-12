# frozen_string_literal: true

# One subscriber's day of form activity, assembled for the daily digest.
#
# There is no event table behind this. The three things a subscription can
# follow are already recorded as a side effect of normal work -- submissions
# carry created_at, RecordEdit rows carry every field that moved, and
# StatusChange rows carry every transition -- so a digest is a time-boxed read
# over data that already exists. Nothing has to be written at event time for a
# digest to be complete, and a digest can be rebuilt for any past window.
#
# Used twice per run: FormSubscriptionDigestJob asks #any? to decide whether an
# employee gets mail at all, and FormSubscriptionMailer renders the same object.
module Forms
  class SubscriptionDigest
    attr_reader :employee_id, :since, :through

    def initialize(employee_id:, since:, through: Time.current)
      @employee_id = employee_id.to_s
      @since = since
      @through = through
    end

    def any? = created_submissions.any? || edits.any? || status_changes.any?

    def window = @since..@through

    # New submissions of every form type this subscriber follows for 'created'.
    def created_submissions
      @created_submissions ||= models_for('created').flat_map do |model|
        next [] unless model.column_names.include?('created_at')

        model.where(created_at: window).order(created_at: :asc).to_a
      rescue StandardError => e
        Rails.logger.warn("digest: created lookup failed for #{model}: #{e.message}")
        []
      end
    end

    # Field edits, newest last, over the form types followed for 'edited'.
    def edits
      @edits ||= begin
        types = form_types_for('edited')
        types.empty? ? [] : RecordEdit.where(record_type: types, created_at: window).order(:created_at).to_a
      end
    end

    # Status transitions over the form types followed for 'status_changed'.
    # Rows with no from_status are a submission's opening status rather than a
    # transition, and belong to the 'created' event instead.
    def status_changes
      @status_changes ||= begin
        types = form_types_for('status_changed')
        if types.empty?
          []
        else
          StatusChange.where(trackable_type: types, created_at: window)
                      .where.not(from_status: nil)
                      .order(:created_at).to_a
        end
      end
    end

    # Edits grouped by the record they belong to, so the mail can show one block
    # per submission rather than a flat list of columns.
    def edits_by_record
      edits.group_by { |edit| [edit.record_type, edit.record_id] }
    end

    def total_events = created_submissions.size + edits.size + status_changes.size

    private

    # Form class names this subscriber follows for one event, at digest cadence.
    def form_types_for(event)
      @form_types_for ||= {}
      @form_types_for[event] ||= begin
        subscriptions = Forms::Subscription.for_employee(@employee_id).to_a
        group_ids = EmployeeGroup.where(EmployeeID: @employee_id).pluck(:GroupID)
        subscriptions.concat(Forms::Subscription.for_group(group_ids).to_a) if group_ids.present?
        column = Forms::Subscription::EVENT_COLUMNS.fetch(event)
        subs = subscriptions.select { |subscription| subscription.delivery_mode == Forms::Subscription::DAILY_DIGEST && subscription[column] }
        Forms::Subscription.covered_form_types(subs)
      end
    end

    def models_for(event)
      form_types_for(event).filter_map do |class_name|
        model = class_name.safe_constantize
        model if model.is_a?(Class) && model < ActiveRecord::Base
      end
    end
  end
end
