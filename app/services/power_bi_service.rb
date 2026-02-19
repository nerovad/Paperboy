# app/services/power_bi_service.rb
class PowerBiService
  class PowerBiError < StandardError; end

  def initialize(user_session)
    @user_session = user_session
  end

  def generate_embed_token(workspace_id, report_id)
    # Check if Power BI is configured
    unless powerbi_configured?
      Rails.logger.warn("Power BI not configured, returning placeholder token")
      return {
        token: "PLACEHOLDER_TOKEN_#{Time.current.to_i}",
        expiration: 1.hour.from_now
      }
    end

    # Get Azure AD access token
    access_token = get_azure_ad_token

    # Call Power BI REST API to generate embed token
    embed_token_response = request_embed_token(access_token, workspace_id, report_id)

    {
      token: embed_token_response['token'],
      expiration: embed_token_response['expiration']
    }
  rescue => e
    Rails.logger.error("Power BI embed token generation failed: #{e.message}")
    Rails.logger.error(e.backtrace.first(5).join("\n"))
    raise PowerBiError, "Failed to generate embed token: #{e.message}"
  end

  private

  def powerbi_configured?
    ENV['POWERBI_CLIENT_ID'].present? &&
      ENV['POWERBI_CLIENT_SECRET'].present? &&
      ENV['POWERBI_TENANT_ID'].present?
  end

  def get_azure_ad_token
    require 'net/http'
    require 'uri'
    require 'json'

    # Government Cloud endpoint
    authority_url = ENV['POWERBI_AUTHORITY_URL'] || 'https://login.microsoftonline.com'
    tenant_id = ENV['POWERBI_TENANT_ID']

    uri = URI.parse("#{authority_url}/#{tenant_id}/oauth2/v2.0/token")

    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.read_timeout = 10

    request = Net::HTTP::Post.new(uri.request_uri)
    request.set_form_data(
      'grant_type' => 'client_credentials',
      'client_id' => ENV['POWERBI_CLIENT_ID'],
      'client_secret' => ENV['POWERBI_CLIENT_SECRET'],
      'scope' => ENV['POWERBI_SCOPE'] || 'https://analysis.usgovcloudapi.net/powerbi/api/.default'
    )

    response = http.request(request)
    token_data = JSON.parse(response.body)

    if token_data['error']
      raise PowerBiError, "Azure AD token error: #{token_data['error_description']}"
    end

    token_data['access_token']
  end

  def request_embed_token(access_token, workspace_id, report_id)
    require 'net/http'
    require 'uri'
    require 'json'

    # Government Cloud API endpoint
    api_url = ENV['POWERBI_API_URL'] || 'https://api.powerbigov.us'
    uri = URI.parse("#{api_url}/v1.0/myorg/groups/#{workspace_id}/reports/#{report_id}/GenerateToken")

    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.read_timeout = 10

    request = Net::HTTP::Post.new(uri.request_uri)
    request['Authorization'] = "Bearer #{access_token}"
    request['Content-Type'] = 'application/json'

    # Request body - set access level to View
    # Can add RLS (Row-Level Security) identities here if needed
    request.body = {
      accessLevel: 'View'
    }.to_json

    response = http.request(request)
    embed_data = JSON.parse(response.body)

    if embed_data['error']
      error_msg = embed_data['error']['message'] || embed_data['error']['code']
      raise PowerBiError, "Power BI API error: #{error_msg}"
    end

    embed_data
  end

  # Future: Add Row-Level Security (RLS) support
  def request_embed_token_with_rls(access_token, workspace_id, report_id, dataset_id, user_identity)
    require 'net/http'
    require 'uri'
    require 'json'

    api_url = ENV['POWERBI_API_URL'] || 'https://api.powerbigov.us'
    uri = URI.parse("#{api_url}/v1.0/myorg/groups/#{workspace_id}/reports/#{report_id}/GenerateToken")

    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true

    request = Net::HTTP::Post.new(uri.request_uri)
    request['Authorization'] = "Bearer #{access_token}"
    request['Content-Type'] = 'application/json'

    # Add RLS identity
    request.body = {
      accessLevel: 'View',
      identities: [
        {
          username: user_identity[:username],
          roles: user_identity[:roles] || [],
          datasets: [dataset_id]
        }
      ]
    }.to_json

    response = http.request(request)
    JSON.parse(response.body)
  end
end
