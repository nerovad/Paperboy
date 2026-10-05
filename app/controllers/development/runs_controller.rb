# frozen_string_literal: true

module Development
  class RunsController < BaseController
    before_action :set_run, only: :show

    def index
      @groups = ScriptCatalog.groups.filter_map do |group|
        scripts = ScriptCatalog.for_group(group).select { |script| feature?(script[:feature]) }
        [group, scripts] if scripts.any?
      end
      @selected_script = ScriptCatalog.find(params[:script_key])
      @selected_script = nil unless @selected_script && feature?(@selected_script[:feature])
      @show_recent_runs = params[:recent].present?
      @recent_runs = Development::Run.order(created_at: :desc).limit(12)
    end

    def show; end

    def create
      script = ScriptCatalog.find(params[:script_key])
      return redirect_with_alert('That workflow is not available.') unless script && feature?(script[:feature])

      arguments = script.fetch(:arguments).call(params)
      run = Development::Run.create!(
        script_key: script[:key],
        script_label: script[:label],
        command_json: Development::CommandBuilder.new(script, arguments).to_a.to_json,
        requested_by: current_user.email,
        status: 'queued'
      )
      RunScriptJob.perform_later(run.id)
      redirect_to development_run_path(run), notice: "#{script[:label]} queued."
    rescue ArgumentError => e
      redirect_with_alert(e.message)
    end

    private

    def set_run
      @run = Development::Run.find(params[:id])
      return if feature?(ScriptCatalog.find(@run.script_key).fetch(:feature))

      redirect_to development_root_path, alert: 'You do not have access to that workflow.'
    end

    def feature?(key)
      helpers.can_use_app_feature?('development', key)
    end

    helper_method :feature?

    def redirect_with_alert(message)
      redirect_to development_root_path, alert: message
    end
  end
end
