# frozen_string_literal: true

module Coa
  class CrudController < BaseController
    before_action :set_record, only: %i[show edit update destroy]

    class_attribute :coa_model_class, instance_accessor: false

    helper_method :model_class,
                  :records,
                  :record,
                  :resource_name,
                  :resource_title,
                  :collection_title,
                  :primary_key_columns,
                  :display_columns,
                  :editable_columns,
                  :collection_path,
                  :member_path,
                  :new_record_path,
                  :edit_record_path

    def index
      @records = model_class.order(primary_key_columns.index_with(:asc))
      render "coa/crud/index"
    end

    def show
      render "coa/crud/show"
    end

    def new
      @record = model_class.new
      render "coa/crud/new"
    end

    def edit
      render "coa/crud/edit"
    end

    def create
      @record = model_class.new(record_params)

      if @record.save
        redirect_to member_path(@record), notice: "#{resource_name} was created."
      else
        render "coa/crud/new", status: :unprocessable_entity
      end
    end

    def update
      if @record.update(record_params)
        redirect_to member_path(@record), notice: "#{resource_name} was updated."
      else
        render "coa/crud/edit", status: :unprocessable_entity
      end
    end

    def destroy
      @record.destroy!
      redirect_to collection_path, notice: "#{resource_name} was deleted."
    end

    private

    def model_class
      self.class.coa_model_class
    end

    attr_reader :records, :record

    def resource_name
      model_class.model_name.human
    end

    def resource_title
      resource_name
    end

    def collection_title
      model_class.model_name.human(count: 2)
    end

    def primary_key_columns
      Array(model_class.primary_key)
    end

    def display_columns
      model_class.column_names
    end

    def editable_columns
      display_columns - model_class.readonly_attributes.to_a
    end

    def record_params
      params.require(model_class.model_name.param_key).permit(editable_columns)
    end

    def set_record
      key = primary_key_columns.one? ? params[:id] : params.extract_value(:id)
      @record = model_class.find(key)
    end

    def collection_path(klass = model_class)
      public_send("coa_#{route_collection_name(klass)}_path")
    end

    def member_path(row)
      public_send("coa_#{route_member_name(row.class)}_path", row)
    end

    def new_record_path
      public_send("new_coa_#{route_member_name(model_class)}_path")
    end

    def edit_record_path(row)
      public_send("edit_coa_#{route_member_name(row.class)}_path", row)
    end

    def route_collection_name(klass)
      coa_route_names.fetch(klass.name).fetch(:collection)
    end

    def route_member_name(klass)
      coa_route_names.fetch(klass.name).fetch(:member)
    end

    def coa_route_names
      {
        "Coa::Agency" => { collection: "agencies", member: "agency" },
        "Coa::Activity" => { collection: "activities", member: "activity" },
        "Coa::Department" => { collection: "departments", member: "department" },
        "Coa::Division" => { collection: "divisions", member: "division" },
        "Coa::Function" => { collection: "functions", member: "function" },
        "Coa::Fund" => { collection: "funds", member: "fund" },
        "Coa::MajorProgram" => { collection: "major_programs", member: "major_program" },
        "Coa::Object" => { collection: "objects", member: "object" },
        "Coa::ObjectInference" => { collection: "object_inferences", member: "object_inference" },
        "Coa::Phase" => { collection: "phases", member: "phase" },
        "Coa::Program" => { collection: "programs", member: "program" },
        "Coa::RevenueSource" => { collection: "revenue_sources", member: "revenue_source" },
        "Coa::SubUnit" => { collection: "sub_units", member: "sub_unit" },
        "Coa::Task" => { collection: "tasks", member: "task" },
        "Coa::Unit" => { collection: "units", member: "unit" }
      }
    end
  end
end
