# frozen_string_literal: true

module DevelopmentHelper
  def development_group_label(group)
    {
      'workstation' => 'Workstation',
      'quality' => 'Quality',
      'environment' => 'Environment',
      'deployments' => 'Deployments',
      'collaboration' => 'Collaboration'
    }.fetch(group, group.humanize)
  end

  def development_button_class(script)
    case script[:feature]
    when 'deploy_production', 'deploy_stage', 'deploy_aim', 'csr' then 'warning'
    when 'environment' then 'info'
    else 'approve'
    end
  end

  def development_field(script)
    script[:key]
  end
end
