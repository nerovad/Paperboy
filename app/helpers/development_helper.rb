# frozen_string_literal: true

module DevelopmentHelper
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
end
