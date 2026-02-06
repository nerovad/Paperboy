class TeamsNotifier
  def self.send_cir_alert(cir)
    webhook_url = ENV['TEAMS_WEBHOOK_URL']
    return unless webhook_url.present?

    payload = build_adaptive_card(cir)
    post_to_teams(webhook_url, payload)
  rescue => e
    Rails.logger.error("TeamsNotifier failed: #{e.message}")
  end

  private

  def self.build_adaptive_card(cir)
    {
      type: "message",
      attachments: [
        {
          contentType: "application/vnd.microsoft.card.adaptive",
          contentUrl: nil,
          content: {
            "$schema": "http://adaptivecards.io/schemas/adaptive-card.json",
            type: "AdaptiveCard",
            version: "1.4",
            body: [
              {
                type: "TextBlock",
                size: "Large",
                weight: "Bolder",
                text: "🚨 Immediate CIR Submitted",
                style: "heading"
              },
              {
                type: "FactSet",
                facts: [
                  { title: "Incident Type", value: cir.incident_type.to_s },
                  { title: "Location", value: cir.location.to_s },
                  { title: "Urgency", value: cir.urgency.to_s },
                  { title: "Impact", value: cir.impact.to_s },
                  { title: "Reporter", value: cir.name.to_s },
                  { title: "Submitted", value: cir.created_at&.strftime("%b %d, %Y %I:%M %p").to_s }
                ]
              },
              {
                type: "TextBlock",
                text: "**Details:** #{cir.incident_details.to_s.truncate(500)}",
                wrap: true
              }
            ],
            actions: [
              {
                type: "Action.OpenUrl",
                title: "View in Paperboy",
                url: Rails.application.routes.url_helpers.critical_information_reporting_url(cir, host: ENV.fetch('APP_HOST', 'localhost:3000'))
              }
            ]
          }
        }
      ]
    }
  end

  def self.post_to_teams(webhook_url, payload)
    require 'net/http'
    require 'uri'
    require 'json'

    uri = URI.parse(webhook_url)

    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.read_timeout = 10
    http.open_timeout = 5

    request = Net::HTTP::Post.new(uri.request_uri)
    request['Content-Type'] = 'application/json'
    request.body = payload.to_json

    response = http.request(request)

    unless response.is_a?(Net::HTTPSuccess)
      Rails.logger.error("TeamsNotifier HTTP #{response.code}: #{response.body}")
    end
  end
end
