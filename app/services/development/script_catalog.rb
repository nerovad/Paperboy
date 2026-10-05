# frozen_string_literal: true

module Development
  module ScriptCatalog
    module_function

    def groups
      %w[workstation quality environment deployments collaboration]
    end

    def for_group(group)
      scripts.select { |script| script[:group] == group }
    end

    def find(key)
      scripts.find { |script| script[:key] == key.to_s }
    end

    def scripts
      @scripts ||= [
        script('start_local', 'Start Local App', 'workstation', 'local', 'dev-local',
               'Start Puma, Solid Queue, and Dart Sass on a workstation.',
               port_args(cron: true, no_jobs: true)),
        script('stop_local', 'Stop Local App', 'workstation', 'local', 'stopservers',
               'Stop Paperboy processes for a port.', port_args),
        script('unit_test', 'Run Unit Tests', 'quality', 'tests', 'unit-test',
               'Run RuboCop, Brakeman, bundle-audit, and Rails tests.',
               ->(params) { optional_target(params[:target]) }),
        script('environment_check', 'Check Environment', 'environment', 'environment', 'env-pull',
               'Compare .env with LockBox without changing files.',
               lockbox_args(check: true)),
        script('environment_pull', 'Pull Environment', 'environment', 'environment', 'env-pull',
               'Refresh .env from LockBox.', lockbox_args),
        script('status_report', 'Gitea Status Report', 'collaboration', 'gitea', 'status-report',
               'Read the current issues, pull requests, and milestones.',
               ->(params) { ['--stale-days', integer(params[:stale_days], default: 30)] }),
        script('tag_commit', 'Tag Checked Commit', 'deployments', 'deployments', 'tag-master-commit',
               'Create and push the annotated release tag.',
               ->(params) { optional_value(params[:commit]) }),
        script('deploy_dev', 'Deploy Development', 'deployments', 'deploy_dev', 'deploy-dev',
               'Pull a branch, test it, sync definitions, and restart development.',
               ->(params) { [required_value(params[:branch], 'Branch')] }),
        script('deploy_stage', 'Deploy Stage', 'deployments', 'deploy_stage', 'deploy-stage',
               'Deploy a checked release tag to stage.',
               ->(params) { [required_value(params[:tag], 'Release tag')] }),
        script('deploy_production', 'Deploy Production', 'deployments', 'deploy_production', 'deploy',
               'Deploy a checked release tag to production.',
               ->(params) { [required_value(params[:tag], 'Release tag')] }),
        script('deploy_aim_workers', 'Deploy AIM Workers', 'deployments', 'deploy_aim', 'deploy-aim-workers',
               'Dry-run or apply the AIM worker deployment.',
               ->(params) { deploy_aim_args(params) }),
        script('generate_csr', 'Generate CSR', 'environment', 'csr', 'gen-csr',
               'Generate an environment certificate signing request.',
               ->(params) { csr_args(params) }),
        script('create_issue', 'Create Gitea Issue', 'collaboration', 'gitea', 'new-issue',
               'Create a typed, labeled Paperboy issue.',
               ->(params) { issue_args(params) }),
        script('update_issue', 'Update Gitea Issue', 'collaboration', 'gitea', 'update-issue',
               'Preview or apply labels and milestone changes to an issue.',
               ->(params) { update_issue_args(params) })
      ]
    end

    def script(key, label, group, feature, bin, description, arguments)
      { key: key, label: label, group: group, feature: feature, bin: bin,
        description: description, arguments: arguments }
    end

    def port_args(cron: false, no_jobs: false)
      lambda do |params|
        port = optional_integer(params[:port])
        args = port ? [port] : []
        args << '--cron' if cron && truthy?(params[:cron])
        args << '--no-jobs' if no_jobs && truthy?(params[:no_jobs])
        args
      end
    end

    def lockbox_args(check: false)
      lambda do |params|
        args = []
        args << '--check' if check
        args << '--no-pull' if truthy?(params[:no_pull])
        args << '--prune' if !check && truthy?(params[:prune])
        args.push('--lockbox', path_value(params[:lockbox])) if params[:lockbox].present?
        args
      end
    end

    def deploy_aim_args(params)
      args = []
      args << '--apply' if truthy?(params[:apply])
      args << '--v2' if truthy?(params[:v2])
      args.push('--lockbox', path_value(params[:lockbox])) if params[:lockbox].present?
      args.push('--target', path_value(params[:target])) if params[:target].present?
      args
    end

    def csr_args(params)
      [required_value(params[:environment], 'Environment'), required_value(params[:server_ip], 'Server IP'),
       *params[:extra_dns_names].to_s.split(/\s+/).reject(&:blank?).map { |name| dns_name(name) }]
    end

    def issue_args(params)
      args = ['--type', required_value(params[:issue_type], 'Issue type'), '--title', required_value(params[:title], 'Title')]
      args += ['--body', params[:body].to_s] if params[:body].present?
      args << '--no-milestone' if truthy?(params[:no_milestone])
      args
    end

    def update_issue_args(params)
      args = ['--issue', integer(params[:issue], required: 'Issue')]
      params[:labels].to_s.split(',').map(&:strip).reject(&:blank?).each { |label| args += ['--add-label', label] }
      args += ['--milestone', params[:milestone].to_s] if params[:milestone].present?
      args << '--apply' if truthy?(params[:apply])
      args
    end

    def optional_target(value)
      value.present? ? [path_value(value)] : []
    end

    def optional_value(value)
      value.present? ? [value.to_s] : []
    end

    def required_value(value, label)
      raise ArgumentError, "#{label} is required." if value.blank?

      value.to_s.strip
    end

    def path_value(value)
      value.to_s.strip.presence || raise(ArgumentError, 'Path cannot be blank.')
    end

    def dns_name(value)
      raise ArgumentError, "Invalid DNS name: #{value}" unless value.match?(/\A[A-Za-z0-9][A-Za-z0-9.-]*\z/)

      value
    end

    def optional_integer(value)
      return if value.blank?

      integer(value)
    end

    def integer(value, default: nil, required: nil)
      return default if value.blank? && default
      raise ArgumentError, "#{required} must be a number." unless value.to_s.match?(/\A\d+\z/)

      value.to_i.to_s
    end

    def truthy?(value)
      %w[1 true on].include?(value.to_s)
    end
  end
end
