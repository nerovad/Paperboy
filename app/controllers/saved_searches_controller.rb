class SavedSearchesController < ApplicationController
  def create
    employee_id = session.dig(:user, "employee_id").to_s

    saved_search = SavedSearch.find_or_initialize_by(
      employee_id: employee_id,
      name: params[:name]
    )
    saved_search.filters = filter_params.to_h
    saved_search.save!

    redirect_to submissions_path(saved_search.filters.merge(saved_search_id: saved_search.id)),
                notice: "Search \"#{saved_search.name}\" saved."
  rescue ActiveRecord::RecordInvalid => e
    redirect_to submissions_path, alert: "Could not save search: #{e.record.errors.full_messages.join(', ')}"
  end

  def destroy
    employee_id = session.dig(:user, "employee_id").to_s
    saved_search = SavedSearch.find_by!(id: params[:id], employee_id: employee_id)
    saved_search.destroy!

    redirect_to submissions_path, notice: "Search \"#{saved_search.name}\" deleted."
  rescue ActiveRecord::RecordNotFound
    redirect_to submissions_path, alert: "Saved search not found."
  end

  private

  def filter_params
    params.permit(
      :filter_type, :filter_title, :filter_category, :filter_status,
      :filter_date_from, :filter_date_to, :filter_employee_name, :filter_employee_id,
      :sort_by, :sort_direction
    )
  end
end
