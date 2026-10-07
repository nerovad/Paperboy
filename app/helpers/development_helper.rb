# frozen_string_literal: true

module DevelopmentHelper
  # bin/new-issue assigns this project when the form does not name one.
  GITEA_PROJECT_DEFAULT = 'Powerpuff Girls'

  def development_group_label(group)
    {
      'quality' => 'Quality',
      'environment' => 'Environment',
      'deployments' => 'Deployments',
      'collaboration' => 'Collaboration'
    }.fetch(group, group.humanize)
  end

  def development_button_class(script)
    return 'deny' if script[:key] == 'clean_worktree'
    return 'warning' if %w[deploy_stage deploy_production deploy_aim_workers generate_csr].include?(script[:key])
    return 'info' if script[:feature] == 'environment'

    'approve'
  end

  # Dry-run submits (update-issue preview) carry no confirm. The apply
  # button in the card owns that message.
  def development_confirm_data(script)
    return {} if script[:confirm].blank? || script[:confirm_when] == 'apply'

    data = { turbo_confirm: script[:confirm] }
    return data unless script[:key] == 'clean_worktree'

    data.merge(confirm_title: 'Clean worktree', confirm_label: 'Clean')
  end

  def development_field(script)
    script[:key]
  end

  def development_label_names(choices)
    choice_names(choices, 'labels', 'name')
  end

  # The template radio owns bug, feature, chore, and infrastructure.
  def development_update_label_names(choices)
    development_label_names(choices).reject { |name| Paperboy::Gitea::IssueTemplate::TYPE_ORDER.include?(name) }
  end

  def development_milestone_titles(choices)
    choice_names(choices, 'milestones', 'title')
  end

  def development_project_titles(choices)
    choice_names(choices, 'projects', 'title')
  end

  def development_project_default(choices)
    titles = development_project_titles(choices)
    titles.include?(GITEA_PROJECT_DEFAULT) ? GITEA_PROJECT_DEFAULT : '__none__'
  end

  def development_column_choices(choices)
    Array(choices && choices['projects']).flat_map do |project|
      Array(project['columns']).filter_map do |column|
        title = column['title'].to_s
        next if title.empty?

        ["#{project['title']} — #{title}", title]
      end
    end
  end

  private

  def choice_names(choices, collection, field)
    Array(choices && choices[collection]).filter_map { |row| row[field].to_s.presence }
  end
end
