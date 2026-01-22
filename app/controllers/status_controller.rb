# app/controllers/status_controller.rb
class StatusController < ApplicationController
  include Filterable

  def index
    employee_id = session.dig(:user, "employee_id").to_s
    @is_manager = current_user&.in_group?("Status Managers")
    @view_mode = @is_manager && params[:view_mode] == "team" ? "team" : "personal"

    @status_items = []

    if @view_mode == "team"
      # Team view - all submissions
      @status_items += ParkingLotSubmission.includes(:status_changes).map do |f|
        build_status_item(f, "Parking Lot", parking_lot_submission_path(f))
      end

      @status_items += ProbationTransferRequest.includes(:status_changes).map do |f|
        build_status_item(f, "Probation Transfer", probation_transfer_request_path(f))
      end

      @status_items += CriticalInformationReporting.includes(:status_changes).map do |f|
        build_status_item(f, "Critical Information Report", edit_critical_information_reporting_path(f))
      end
    else
      # Personal view - user's own submissions only
      @status_items += ParkingLotSubmission.for_employee(employee_id).includes(:status_changes).map do |f|
        build_status_item(f, "Parking Lot", parking_lot_submission_path(f))
      end

      @status_items += ProbationTransferRequest.for_employee(employee_id).includes(:status_changes).map do |f|
        build_status_item(f, "Probation Transfer", probation_transfer_request_path(f))
      end

      @status_items += CriticalInformationReporting.for_employee(employee_id).includes(:status_changes).map do |f|
        build_status_item(f, "Critical Information Report", edit_critical_information_reporting_path(f))
      end
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

  def build_status_item(submission, type, path)
    {
      id: submission.id,
      type: type,
      title: "#{type} ##{submission.id}",
      status: submission.status_label,
      submitted_at: submission.created_at,
      updated_at: submission.updated_at,
      path: path,
      employee_id: submission.employee_id,
      employee_name: submission.name,
      status_changes: submission.status_changes.chronological.to_a
    }
  end

  def status_field_mappings
    mappings = {
      types: ->(item) { item[:type] },
      statuses: ->(item) { item[:status].to_s.tr('_', ' ').titleize }
    }

    if @view_mode == "team"
      mappings[:employee_names] = ->(item) { item[:employee_name] }
      mappings[:employee_ids] = ->(item) { item[:employee_id] }
    end

    mappings
  end

  def status_filter_configs
    configs = [
      { param: :filter_type, extractor: ->(item) { item[:type] } },
      { param: :filter_status, extractor: ->(item) { item[:status].to_s.tr('_', ' ').titleize } }
    ]

    if @view_mode == "team"
      configs << { param: :filter_employee_name, extractor: ->(item) { item[:employee_name] } }
      configs << { param: :filter_employee_id, extractor: ->(item) { item[:employee_id] } }
    end

    configs
  end

  def status_date_filters
    [
      { param: :filter_date_from, extractor: ->(item) { item[:submitted_at] }, comparison: :from },
      { param: :filter_date_to, extractor: ->(item) { item[:submitted_at] }, comparison: :to }
    ]
  end

  def status_sort_configs
    configs = {
      'type' => ->(item) { item[:type].to_s },
      'title' => ->(item) { item[:title].to_s },
      'status' => ->(item) { item[:status].to_s },
      'submitted_at' => ->(item) { item[:submitted_at].to_s },
      'updated_at' => ->(item) { item[:updated_at].to_s }
    }

    if @view_mode == "team"
      configs['employee_name'] = ->(item) { item[:employee_name].to_s }
      configs['employee_id'] = ->(item) { item[:employee_id].to_s }
    end

    configs
  end
end
