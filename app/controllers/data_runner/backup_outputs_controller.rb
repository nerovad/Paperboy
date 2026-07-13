# frozen_string_literal: true

module DataRunner
  class BackupOutputsController < ApplicationController
    SORT_COLUMNS = %w[file size modified].freeze
    SORT_DIRECTIONS = %w[asc desc].freeze

    before_action :require_login
    before_action :set_dsl
    helper_method :backup_sort_direction

    def index
      @sort = SORT_COLUMNS.include?(params[:sort]) ? params[:sort] : 'file'
      @direction = SORT_DIRECTIONS.include?(params[:direction]) ? params[:direction] : 'asc'
      @files = sort_files(WorkflowOutputs.new(@dsl).backup_files)
    end

    def destroy
      file = WorkflowOutputs.new(@dsl).delete_backup_file!(params[:path])
      redirect_to backup_outputs_data_runner_dsl_path(@dsl.slug), notice: "#{file.basename} deleted.", status: :see_other
    end

    def destroy_all
      files = WorkflowOutputs.new(@dsl).delete_backup_files!
      redirect_to backup_outputs_data_runner_dsl_path(@dsl.slug),
                  notice: "#{files.size} backup files deleted.",
                  status: :see_other
    end

    private

    def set_dsl
      @dsl = DslCatalog.find!(params[:name])
    end

    def sort_files(files)
      sorted = files.sort_by do |file|
        case @sort
        when 'size' then file.size
        when 'modified' then file.mtime
        else file.basename.to_s.downcase
        end
      end
      @direction == 'desc' ? sorted.reverse : sorted
    end

    def backup_sort_direction(column)
      @sort == column && @direction == 'asc' ? 'desc' : 'asc'
    end
  end
end
