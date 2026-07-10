# frozen_string_literal: true

# Teams incoming-webhook (Azure Logic App) for Critical Information Reporting
# alerts. The URL carries a live signing secret, so it is supplied per server
# via TEAMS_WEBHOOK_URL in that server's .env rather than committed here.
Rails.application.config.teams_webhook_url = ENV.fetch('TEAMS_WEBHOOK_URL', nil)

Rails.logger.warn('TEAMS_WEBHOOK_URL is not set; Teams CIR alerts are disabled') if Rails.application.config.teams_webhook_url.blank?
