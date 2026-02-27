# app/controllers/task_reassignments_controller.rb

class TaskReassignmentsController < ApplicationController
  before_action :require_login

  def reassign
    task = find_task(params[:task_type], params[:task_id])
    current_employee_id = session.dig(:user, "employee_id").to_s

    unless task
      redirect_to inbox_queue_path, alert: "Task not found." and return
    end

    reassignment = task.reassign_to!(
      new_assignee_id: params[:to_employee_id],
      reassigned_by_id: current_employee_id,
      reason: params[:reason]
    )

    # Send email notification
    TaskReassignmentMailer.reassignment_notification(reassignment.id).deliver_later

    redirect_to inbox_queue_path, notice: "Task reassigned successfully."
  rescue StandardError => e
    Rails.logger.error("Reassignment failed: #{e.message}")
    redirect_to inbox_queue_path, alert: "Failed to reassign task: #{e.message}"
  end

  def take_back
    task = find_task(params[:task_type], params[:task_id])
    current_employee_id = session.dig(:user, "employee_id").to_s

    unless task
      redirect_to inbox_queue_path, alert: "Task not found." and return
    end

    unless task.can_take_back?(current_employee_id)
      redirect_to inbox_queue_path, alert: "You cannot take back this task." and return
    end

    reassignment = task.take_back!(current_employee_id)

    # Send notification
    TaskReassignmentMailer.take_back_notification(reassignment.id).deliver_later

    redirect_to inbox_queue_path, notice: "Task returned to you."
  rescue StandardError => e
    Rails.logger.error("Take back failed: #{e.message}")
    redirect_to inbox_queue_path, alert: "Failed to take back task: #{e.message}"
  end

  def history
    task = find_task(params[:task_type], params[:task_id])

    unless task
      render json: { error: "Task not found" }, status: :not_found and return
    end

    @reassignments = task.task_reassignments.order(created_at: :desc)

    render json: @reassignments.map { |r|
      {
        id: r.id,
        from: "#{r.from_employee&.first_name} #{r.from_employee&.last_name}",
        to: "#{r.to_employee&.first_name} #{r.to_employee&.last_name}",
        reassigned_by: "#{r.reassigned_by_employee&.first_name} #{r.reassigned_by_employee&.last_name}",
        reason: r.reason,
        created_at: r.created_at.strftime("%Y-%m-%d %H:%M")
      }
    }
  rescue StandardError => e
    Rails.logger.error("History retrieval failed: #{e.message}")
    render json: { error: "Failed to retrieve history" }, status: :internal_server_error
  end

  private

  def find_task(task_type, task_id)
    case task_type
    when "CriticalInformationReporting"
      CriticalInformationReporting.find_by(id: task_id)
    when "ParkingLotSubmission"
      ParkingLotSubmission.find_by(id: task_id)
    when "ProbationTransferRequest"
      ProbationTransferRequest.find_by(id: task_id)
    else
      nil
    end
  end

  def require_login
    unless session[:user].present?
      redirect_to root_path, alert: "Please log in."
    end
  end
end
