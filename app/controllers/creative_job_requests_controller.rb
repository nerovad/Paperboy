class CreativeJobRequestsController < ApplicationController
  def new
    @creative_job_request = CreativeJobRequest.new
  end

  def create
    @creative_job_request = CreativeJobRequest.new(creative_job_request_params)
    if @creative_job_request.save
      redirect_to root_path, notice: "Creative Job Request submitted successfully."
    else
      render :new, status: :unprocessable_entity
    end
  end

  private

  def creative_job_request_params
    params.require(:creative_job_request).permit(
      :job_id, :job_title, :job_type, :job_agency, :job_division,
      :job_department, :job_unit, :asset_type, :employee_name,
      :location, :date, :description
    )
  end
end
