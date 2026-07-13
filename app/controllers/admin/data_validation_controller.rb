# frozen_string_literal: true

module Admin
  class DataValidationController < ApplicationController
    before_action :require_system_admin

    def index
      validator = EmployeeDataValidator.new
      @results = validator.validate_all
      @summary = validator.summary(@results)

      respond_to do |format|
        format.html { apply_filters }
        format.csv  { send_csv }
      end
    end

    private

    def apply_filters
      @filter = params[:filter] || 'all'
      @search = params[:search]&.strip

      @filtered_results = filter_results(@results)

      if @search.present?
        term = @search.downcase
        @filtered_results = @filtered_results.select do |r|
          emp = r.employee
          "#{emp.first_name} #{emp.last_name}".downcase.include?(term) ||
            emp.employee_id.to_s.include?(term) ||
            emp.email&.downcase&.include?(term) ||
            emp.agency&.downcase&.include?(term) ||
            emp.unit&.downcase&.include?(term)
        end
      end

      @total_filtered = @filtered_results.size
      @page = [params[:page].to_i, 1].max
      @per_page = 50
      @total_pages = (@total_filtered / @per_page.to_f).ceil
      @page = [@page, @total_pages].min if @total_pages.positive?
      @filtered_results = @filtered_results[(@page - 1) * @per_page, @per_page] || []
    end

    def send_csv
      @filter = params[:filter] || 'all'
      rows = filter_results(@results)
      filename = "data_validation_#{@filter}_#{Date.current.iso8601}.csv"

      csv_data = CSV.generate do |csv|
        csv << ['Employee ID', 'First Name', 'Last Name', 'Email', 'Agency', 'Department', 'Unit',
                'Supervisor ID', 'Work Phone', 'Status', 'Errors', 'Warnings', 'Issues']

        rows.each do |result|
          emp = result.employee
          csv << [
            emp.employee_id,
            emp.first_name,
            emp.last_name,
            emp.email,
            emp.agency,
            emp.department,
            emp.unit,
            emp.supervisor_id,
            emp.work_phone,
            if result.error_count.positive?
              'error'
            else
              (result.warning_count.positive? ? 'warning' : 'clean')
            end,
            result.error_count,
            result.warning_count,
            result.issues.map(&:message).join('; ')
          ]
        end
      end

      send_data csv_data, filename: filename, type: 'text/csv'
    end

    def filter_results(results)
      case @filter
      when 'errors'
        results.select { |r| r.error_count.positive? }
      when 'warnings'
        results.select { |r| r.valid? && r.warning_count.positive? }
      when 'valid'
        results.select(&:valid?)
      when 'email'
        results.select { |r| r.issues.any? { |i| i.category == :email } }
      when 'org_chain'
        results.select { |r| r.issues.any? { |i| i.category == :org_chain } }
      when 'supervisor'
        results.select { |r| r.issues.any? { |i| i.category == :supervisor } }
      when 'agency'
        results.select { |r| r.issues.any? { |i| i.category == :agency } }
      when 'groups'
        results.select { |r| r.issues.any? { |i| i.category == :groups } }
      when 'phone'
        results.select { |r| r.issues.any? { |i| i.category == :phone } }
      when 'name'
        results.select { |r| r.issues.any? { |i| i.category == :name } }
      else
        results
      end
    end
  end
end
