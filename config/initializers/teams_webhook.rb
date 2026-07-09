# Teams incoming-webhook (Azure Logic App) for Critical Information Reporting
# alerts. The URL carries a live signing secret, so it is supplied per server
# via TEAMS_WEBHOOK_URL in that server's .env rather than committed here.
#   dev   -> Dev Teams channel
#   stage -> Stage Teams channel
#   prod  -> Prod Teams channel
Rails.application.config.teams_webhook_url = ENV["TEAMS_WEBHOOK_URL"]

if Rails.application.config.teams_webhook_url.blank?
  Rails.logger.warn("TEAMS_WEBHOOK_URL is not set; Teams CIR alerts are disabled")
end
