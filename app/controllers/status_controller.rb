# app/controllers/status_controller.rb
class StatusController < ApplicationController
  include Filterable

  def index
    employee_id = session[:user]["employee_id"].to_s

    @status_items = []

    @status_items += ParkingLotSubmission.for_employee(employee_id).map do |f|
      {
        type: "Parking Lot",
        title: "Parking Permit ##{f.id}",
        status: f.status_label,
        submitted_at: f.created_at,
        updated_at: f.updated_at,
        path: parking_lot_submission_path(f)
      }
    end

    @status_items += ProbationTransferRequest.for_employee(employee_id).map do |f|
      {
        type: "Probation Transfer",
        title: "Transfer Request ##{f.id}",
        status: f.status_label,
        submitted_at: f.created_at,
        updated_at: f.updated_at,
        path: probation_transfer_request_path(f)
      }
    end

    @status_items += CriticalInformationReporting.for_employee(employee_id).map do |f|
      {
        type: "Critical Information Report",
        title: "CIR ##{f.id}",
        status: f.status_label,
        submitted_at: f.created_at,
        updated_at: f.updated_at,
        path: edit_critical_information_reporting_path(f)
      }
    end

    # Collect unique values for filter dropdowns before filtering
    @filter_options = collect_filter_options(@status_items, status_field_mappings)

    # Apply filters
    @status_items = apply_filters(@status_items,
      filter_configs: status_filter_configs,
      date_filters: status_date_filters
    )

    # Apply sorting
    sort_by = params[:sort_by] || 'updated_at'
    sort_direction = params[:sort_direction] || 'desc'

    @status_items = sort_collection(@status_items, sort_by, sort_direction, status_sort_configs, default_sort: 'updated_at')
  end

  private

  def status_field_mappings
    {
      types: ->(item) { item[:type] },
      statuses: ->(item) { item[:status].to_s.tr('_', ' ').titleize }
    }
  end

  def status_filter_configs
    [
      { param: :filter_type, extractor: ->(item) { item[:type] } },
      { param: :filter_status, extractor: ->(item) { item[:status].to_s.tr('_', ' ').titleize } }
    ]
  end

  def status_date_filters
    [
      { param: :filter_date_from, extractor: ->(item) { item[:submitted_at] }, comparison: :from },
      { param: :filter_date_to, extractor: ->(item) { item[:submitted_at] }, comparison: :to }
    ]
  end

  def status_sort_configs
    {
      'type' => ->(item) { item[:type].to_s },
      'title' => ->(item) { item[:title].to_s },
      'status' => ->(item) { item[:status].to_s },
      'submitted_at' => ->(item) { item[:submitted_at].to_s },
      'updated_at' => ->(item) { item[:updated_at].to_s }
    }
  end
end
