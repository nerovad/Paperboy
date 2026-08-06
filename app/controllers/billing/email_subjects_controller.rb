# frozen_string_literal: true

module Billing
  class EmailSubjectsController < BaseController
    before_action :require_system_admin
    before_action :load_subjects

    def show; end

    def update
      values = params.require(:subjects).permit(*@subjects.map(&:billing_type)).to_h
      raise ArgumentError unless values.keys.sort == @subjects.map(&:billing_type).sort

      EmailSubject.transaction do
        @subjects.each do |subject|
          subject.subject_format = values.fetch(subject.billing_type)
          subject.save!
        end
      end
      redirect_to billing_email_subjects_path, notice: 'Email subjects updated.'
    rescue ActiveRecord::ActiveRecordError, ActionController::ParameterMissing, ArgumentError, KeyError => e
      Rails.logger.error("Billing subject update failed: #{e.class}: #{e.message}")
      redirect_to billing_email_subjects_path, alert: 'Email subjects could not be updated.'
    end

    private

    def load_subjects
      active_types = BillingType.where(ACTIVE: true).order(:TYPE)
      subjects_by_type = EmailSubject.where(billing_type: active_types.map(&:code)).index_by(&:billing_type)
      @subjects = active_types.map do |billing_type|
        subjects_by_type[billing_type.code] || EmailSubject.new(
          billing_type: billing_type.code,
          subject_format: EmailSubject.default_format(billing_type.code)
        )
      end
      @type_names = active_types.index_by(&:code)
    end
  end
end
