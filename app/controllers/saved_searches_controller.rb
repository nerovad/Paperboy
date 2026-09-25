# frozen_string_literal: true

class SavedSearchesController < ApplicationController
  FILTER_KEY = /\Afilter_[a-z0-9_]+\z/
  SORT_KEYS = %w[sort_by sort_direction].freeze

  def create
    employee_id = session.dig(:user, 'employee_id').to_s

    saved_search = SavedSearch.find_or_initialize_by(
      employee_id: employee_id,
      name: params[:name]
    )
    saved_search.filters = filter_params
    saved_search.save!

    redirect_to submissions_path(saved_search.filters.merge(saved_search_id: saved_search.id)),
                notice: "Search \"#{saved_search.name}\" saved."
  rescue ActiveRecord::RecordInvalid => e
    redirect_to submissions_path, alert: "Could not save search: #{e.record.errors.full_messages.join(', ')}"
  end

  def destroy
    employee_id = session.dig(:user, 'employee_id').to_s
    saved_search = SavedSearch.find_by!(id: params[:id], employee_id: employee_id)
    saved_search.destroy!

    redirect_to submissions_path, notice: "Search \"#{saved_search.name}\" deleted."
  rescue ActiveRecord::RecordNotFound
    redirect_to submissions_path, alert: 'Saved search not found.'
  end

  private

  # Every filter on the Submissions page is a `filter_` param, but the set is
  # not fixed: column filters follow each user's layout and custom columns mint
  # their own (see TableColumns), so the permitted keys are read off the
  # request rather than listed here. Blank values mean "All" and are dropped.
  def filter_params
    keys = params.keys.grep(FILTER_KEY)
    params.permit(*SORT_KEYS, *keys, *keys.map { |k| { k => [] } })
          .to_h.compact_blank
  end
end
