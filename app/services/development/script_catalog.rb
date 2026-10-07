# frozen_string_literal: true

module Development
  # The catalog keeps the allowlisted scripts and their form argument
  # builders together so adding a workflow cannot silently omit either half.
  # rubocop:disable-next Metrics/ModuleLength
  module ScriptCatalog
    module_function

    # Locked off the Development menu. A future local start stays a different bin.
    OFF_MENU_BINS = %w[dev setup stopservers].freeze

    def groups
      %w[quality environment deployments collaboration]
    end

    def for_group(group)
      scripts.select { |script| script[:group] == group && menu?(script) }
    end

    def find(key)
      scripts.find { |script| script[:key] == key.to_s }
    end

    def menu?(script)
      script.fetch(:menu, true)
    end

    # rubocop:disable-next Metrics/MethodLength
    def scripts
      @scripts ||= [
        script('unit_test', 'Run Unit Tests', 'quality', 'local', 'unit-test',
               'Run RuboCop, Brakeman, bundle-audit, and Rails tests.',
               ->(params) { optional_target(params[:target]) }),
        script('environment_check', 'Check Environment', 'environment', 'environment', 'env-pull',
               'Compare .env with LockBox without changing files.',
               lockbox_args(check: true)),
        script('environment_pull', 'Pull Environment', 'environment', 'environment', 'env-pull',
               'Refresh .env from LockBox.', lockbox_args,
               confirm: 'Refresh .env from LockBox? This replaces the environment file.'),
        script('status_report', 'Gitea Status Report', 'collaboration', 'gitea', 'status-report',
               'Read the current issues, pull requests, and milestones.',
               ->(params) { ['--stale-days', integer(params[:stale_days], default: 30)] }),
        script('tag_commit', 'Tag Checked Commit', 'deployments', 'deploy', 'tag-master-commit',
               'Create and push the annotated release tag.',
               ->(params) { optional_value(params[:commit]) },
               confirm: 'Tag this commit and push the release tag?'),
        script('deploy_dev', 'Deploy Development', 'deployments', 'deploy', 'deploy-dev',
               'Pull a branch, test it, sync definitions, and restart development.',
               ->(params) { [required_value(params[:branch], 'Branch')] },
               confirm: 'Deploy this branch to the development server? This changes the shared development environment.'),
        # Kept for a later release. Hidden so the menu stays on the dev server.
        script('deploy_stage', 'Deploy Stage', 'deployments', 'deploy', 'deploy-stage',
               'Deploy a checked release tag to stage.',
               ->(params) { [required_value(params[:tag], 'Release tag')] },
               menu: false,
               confirm: 'Run Deploy Stage? This may change a shared environment.'),
        script('deploy_production', 'Deploy Production', 'deployments', 'deploy', 'deploy',
               'Deploy a checked release tag to production.',
               ->(params) { [required_value(params[:tag], 'Release tag')] },
               menu: false,
               confirm: 'Run Deploy Production? This may change a shared environment.'),
        script('deploy_aim_workers', 'Deploy AIM Workers', 'deployments', 'deploy', 'deploy-aim-workers',
               'Dry-run or apply the AIM worker deployment.',
               ->(params) { deploy_aim_args(params) },
               menu: false,
               confirm: 'Run Deploy AIM Workers? This may change a shared environment.'),
        script('generate_csr', 'Generate TLS Certificate Request', 'environment', 'csr', 'gen-csr',
               'Create a private key and certificate request for GSA IT.',
               ->(params) { csr_args(params) },
               confirm: 'Generate a TLS certificate request? This creates a private key.'),
        script('create_issue', 'Create Gitea Issue', 'collaboration', 'gitea', 'new-issue',
               'Create a typed, labeled Paperboy issue from the repository issue template.',
               ->(params) { issue_args(params) },
               confirm: 'Create this Gitea issue?'),
        script('create_pull_request', 'Create Pull Request', 'collaboration', 'gitea',
               'create-pull-request',
               'Open a pull request whose body follows the repository pull request template.',
               ->(params) { pull_request_args(params) },
               confirm: 'Open this pull request on Gitea?'),
        script('update_issue', 'Update Gitea Issue', 'collaboration', 'gitea', 'update-issue',
               'Preview or apply label, milestone, project, and column changes.',
               ->(params) { update_issue_args(params) },
               confirm: 'Apply these changes to the Gitea issue?',
               confirm_when: 'apply'),
        script('clean_worktree', 'Clean Worktree', 'collaboration', 'gitea', 'wt',
               'Remove a merged issue worktree and its local branch.',
               ->(params) { clean_worktree_args(params) },
               confirm: 'Clean this issue worktree? This removes the local worktree and branch.')
      ]
    end

    def script(key, label, group, feature, bin, description, arguments, **options)
      raise ArgumentError, "#{key} uses off-menu bin #{bin}" if OFF_MENU_BINS.include?(bin.to_s)

      { key: key, label: label, group: group, feature: feature, bin: bin,
        description: description, arguments: arguments,
        menu: options.fetch(:menu, true), confirm: options[:confirm],
        confirm_when: options[:confirm_when] }
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
      type = required_value(params[:issue_type], 'Issue type')
      args = ['--type', type, '--title', required_value(params[:title], 'Title'), '--body', issue_body(type, params)]
      label_list(params[:extra_labels]).each { |label| args += ['--label', label] }
      # The runner has no terminal. bin/new-issue prompts for a milestone
      # unless --no-milestone is set, and that read exits 1.
      if params[:milestone].present?
        args += ['--milestone', params[:milestone].to_s.strip]
      else
        args << '--no-milestone'
      end
      args + issue_project_args(params)
    end

    def issue_body(type, params)
      Paperboy::Gitea::IssueTemplate.render(type, issue_answers(params, type))
    rescue Paperboy::Gitea::IssueTemplate::Invalid => e
      raise ArgumentError, e.message
    end

    def issue_answers(params, type)
      raw = params[:answers]
      return {} if raw.blank?

      raw[type] || raw[type.to_sym] || {}
    end

    def issue_project_args(params)
      return ['--no-project'] if truthy?(params[:no_project]) || params[:project].to_s.strip == '__none__'

      project = params[:project].to_s.strip
      project.present? ? ['--project', project] : []
    end

    def pull_request_args(params)
      raise ArgumentError, 'Head branch is required.' if params[:head].blank?

      body = pull_request_body(params)
      args = ['--title', pull_request_title(required_value(params[:title], 'Title'), pull_request_issue(body)),
              '--body', body, '--head', branch_value(params[:head])]
      base = params[:base].to_s.strip
      args + (base.present? ? ['--base', branch_value(base)] : [])
    end

    def pull_request_body(params)
      if params[:answers].present?
        Paperboy::Gitea::PullRequestTemplate.render(params[:answers])
      else
        body = params[:body].to_s
        errors = Paperboy::Gitea::PullRequestTemplate.body_errors(body)
        raise ArgumentError, errors.join(' ') if errors.any?

        body
      end
    rescue Paperboy::Gitea::PullRequestTemplate::Invalid => e
      raise ArgumentError, e.message
    end

    def pull_request_issue(body)
      section = Paperboy::Gitea::IssueTemplate::Sections.section_map(body)['Issue'].to_s
      match = section.match(/\ACloses #(\d+)\z/)
      raise ArgumentError, 'Issue is required.' unless match

      match[1]
    end

    def pull_request_title(title, number)
      return title if title.match?(/\(##{Regexp.escape(number)}\)\s*\z/)

      "#{title} (##{number})"
    end

    def update_issue_args(params)
      added = label_list(params[:labels], params[:add_labels])
      removed = label_list(params[:remove_labels])
      milestone = params[:milestone].to_s.strip
      project = params[:project].to_s.strip
      project = '' if project == '__none__'
      column = params[:column].to_s.strip
      unchanged = added.empty? && removed.empty? && milestone.empty? && project.empty? && column.empty?
      raise ArgumentError, 'At least one update is required.' if unchanged

      args = ['--issue', integer(params[:issue], required: 'Issue')]
      added.each { |label| args += ['--add-label', label] }
      removed.each { |label| args += ['--remove-label', label] }
      args += ['--milestone', milestone] if milestone.present?
      args += ['--project', project] if project.present?
      args += ['--column', column] if column.present?
      args << '--apply' if truthy?(params[:apply])
      args
    end

    def label_list(*values)
      values.flatten.compact.flat_map { |value| value.to_s.split(',') }.map(&:strip).reject(&:blank?)
    end

    def clean_worktree_args(params)
      ['clean', integer(params[:issue], required: 'Issue')]
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

    def branch_value(value)
      value = value.to_s.strip
      raise ArgumentError, 'Branch cannot be blank.' unless value.match?(%r{\A[A-Za-z0-9._/-]+\z})

      value
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
