# frozen_string_literal: true

module Forms
  class WorkProvider < Pfa::Work::Provider
    LEGACY_MODELS = %w[
      ParkingLotSubmission ProbationTransferRequest CriticalInformationReporting
    ].freeze

    def initialize(query_class: Forms::InboxQuery)
      super()
      @query_class = query_class
    end

    def inbox_items(viewer:, filters: {})
      query(filters, viewer).submissions.map { |submission| item_for(submission) }
    end

    def records(viewer:, filters: {})
      model_names.flat_map do |name|
        model = name.safe_constantize
        next [] unless model.is_a?(Class) && model < ApplicationRecord && model.table_exists?

        records_for(model, viewer, filters).map { |submission| item_for(submission) }
      rescue StandardError => e
        Rails.logger.warn("Forms work records skipped #{name}: #{e.message}")
        []
      end
    end

    private

    def query(filters, viewer)
      @query_class.new(
        scoped_employee_ids: filters.fetch(:scoped_employee_ids) { [viewer.fetch(:employee_id).to_s] },
        viewer_grants: filters.fetch(:viewer_grants, []),
        filter_form_type: filters[:form_type],
        date_from: filters[:date_from],
        date_to: filters[:date_to]
      )
    end

    def item_for(submission)
      Pfa::Work::Item.new(
        key: "forms:#{submission.class.name}:#{submission.id}",
        application: :forms,
        source_type: submission.class.name,
        source_id: submission.id,
        reference: Forms::Reference.reference_for(submission),
        title: submission.class.name.demodulize.titleize,
        owner_employee_id: value(submission, :employee_id),
        assignee_employee_id: assignee_for(submission),
        status: value(submission, :status),
        status_category: value(submission, :status_category),
        created_at: value(submission, :created_at),
        updated_at: value(submission, :updated_at),
        actions: [:open],
        metadata: {},
        source: submission
      )
    end

    def assignee_for(submission)
      %i[current_assignee_id approver_id assigned_manager_id supervisor_id].each do |name|
        value = value(submission, name)
        return value if value.present?
      end

      nil
    end

    def value(record, name)
      record.public_send(name) if record.respond_to?(name)
    end

    def model_names
      (LEGACY_MODELS + Forms::Template.pluck(:class_name)).uniq
    end

    def records_for(model, viewer, filters)
      scope = model.all
      scoped_ids = filters.fetch(:scoped_employee_ids) { [viewer.fetch(:employee_id).to_s] }
      grants = filters.fetch(:viewer_grants, [])

      # Own submissions, widened by any visibility grant covering this form —
      # through the same helper the Submissions page uses, so a grant narrowed
      # to one unit narrows here too.
      scope = scope.where(employee_id: scoped_ids) if scoped_ids && model.column_names.include?('employee_id')
      scope = Forms::VisibilityGrant.widen(scope, grants, model)

      scope = scope.where(created_at: Date.parse(filters[:date_from]).beginning_of_day..) if filters[:date_from].present?
      scope = scope.where(created_at: ..Date.parse(filters[:date_to]).end_of_day) if filters[:date_to].present?
      scope
    rescue ArgumentError
      scope
    end
  end
end
