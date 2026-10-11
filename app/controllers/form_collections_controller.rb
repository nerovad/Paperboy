# frozen_string_literal: true

# Creating and curating Form Library collections. Looking at one is the
# library's own page (FormLibraryController); everything here changes one, and
# is the Paperboy `form_collections` feature grant.
#
# An editor is only ever offered the forms their own ACL lets them open, and
# only those can be added or removed by them.
class FormCollectionsController < ApplicationController
  before_action -> { require_app_feature('paperboy', 'form_collections', fallback: form_library_path) }
  before_action :set_collection, only: %i[edit update destroy]
  before_action :load_library

  def new
    @collection = Forms::Collection.new
  end

  def edit; end

  def create
    @collection = Forms::Collection.new(collection_params)
    @collection.created_by_id = current_user.employee_id.to_s
    @collection.created_by_name = "#{current_user.first_name} #{current_user.last_name}".strip
    choose_forms

    if @collection.save
      redirect_to form_library_collection_path(@collection), notice: 'Collection created.'
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    @collection.assign_attributes(collection_params)
    choose_forms

    if @collection.save
      redirect_to form_library_collection_path(@collection), notice: 'Collection updated.'
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @collection.destroy
    redirect_to form_library_path, notice: 'Collection deleted.'
  end

  private

  def set_collection
    @collection = Forms::Collection.includes(:collection_forms).find(params[:id])
  end

  # The forms this editor may open — the only ones the form offers. Setting
  # @library also puts the sidebar in its library mode, which is where these
  # screens are reached from.
  def load_library
    catalog = FormCatalog.new(admin: helpers.system_admin?,
                              permitted_keys: current_user_form_permission_keys)
    @library = FormLibrary.new(catalog, {}, manager: true)
  end

  def choose_forms
    @collection.replace_forms(params.dig(:collection, :form_keys),
                              among: @library.entries.map(&:key),
                              added_by_id: current_user.employee_id.to_s)
  end

  def collection_params
    params.require(:collection).permit(:name, :description)
  end
end
